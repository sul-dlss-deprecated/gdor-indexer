require 'spec_helper'
require 'stringio'

describe SolrDocBuilder do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
    @strio = StringIO.new
  end

  # NOTE:
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope

  context "doc_hash" do
    before(:all) do
      @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>")
      cmd_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'></contentMetadata>"
      @ng_pub_xml = Nokogiri::XML("<publicObject id='druid#{@fake_druid}'>#{cmd_xml}</publicObject>")
    end
    before(:each) do
      @hdor_client = double
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash
    end
    it "id field should be set to druid for non-merged record" do
      @doc_hash[:id].should == @fake_druid
    end
    it "should have a druid field" do
      @doc_hash[:druid].should == @fake_druid
    end
    it "should have the full MODS in the modsxml field for non-merged record" do
      # this fails with equivalent-xml 0.4.1 or 0.4.2, but passes with 0.4.0
      @doc_hash[:modsxml].should be_equivalent_to @mods_xml
    end 
    it "should have an access_facet value of 'Online'" do
      @doc_hash[:access_facet].should == 'Online'
    end
    it "should call the appropriate methods in public_xml_fields" do
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_receive(:display_type)
      sdb.should_receive(:image_ids)
      sdb.should_receive(:doc_hash_from_mods) # avoid expensive parsing unnec for this test
      sdb.doc_hash
    end
    context "img_info field" do
      it "should have img_info as an Array of file ids from content metadata" do
        ng_xml = Nokogiri::XML("<contentMetadata type='image'>
        <resource type='image'><file id='foo' mimetype='image/jp2'/></resource>
        <resource type='image'><file id='bar' mimetype='image/jp2'/></resource></contentMetadata>")
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.should_receive(:doc_hash_from_mods) # avoid expensive parsing unnec for this test
        sdb.stub(:content_md).and_return(ng_xml.root)
        sdb.doc_hash[:img_info].should == ['foo', 'bar']
      end
    end
    it "should call doc_hash_from_mods to populate hash fields from MODS" do
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.should_receive(:doc_hash_from_mods)
      sdb.doc_hash
    end
    context "validation method" do
      it 'should have no validation messages for a complete record' do
        solr_doc = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        hash = solr_doc.doc_hash
        hash[:title_display] = 'title'
        hash[:pub_year_tisim] = 'some year'
        hash[:author_person_display] = 'author'
        hash[:format] = 'Image'
        hash[:language] = 'English'
        messages = solr_doc.validate
        messages.length.should == 0
      end
      it 'should have validation messages for an incomplete record' do
        solr_doc=SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        messages=solr_doc.validate
        messages.length.should > 0
      end
    end  
  end # doc hash

  context 'catkey' do
    before(:all) do
      @identity_md_start = "<publicObject><identityMetadata objectId='#{@fake_druid}'>"
      @identity_md_end = "</identityMetadata></publicObject>"
      @empty_id_md_ng = Nokogiri::XML("#{@identity_md_start}#{@identity_md_end}")
      @barcode_id_md_ng = Nokogiri::XML("#{@identity_md_start}<otherId name=\"barcode\">666</otherId>#{@identity_md_end}")
    end
    before(:each) do
      @hdor_client = double
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
    end
    
    it "should be nil if there is no indication of catkey in identityMetadata" do
      @sdb.stub(:public_xml).and_return(@empty_id_md_ng.root)
      @sdb.catkey.should == nil
    end
    it "should take a catkey in identityMetadata/otherId with name attribute of catkey" do
      ng_xml = Nokogiri::XML("#{@identity_md_start}<otherId name=\"catkey\">12345</otherId>#{@identity_md_end}")
      @sdb.stub(:public_xml).and_return(ng_xml.root)
      @sdb.catkey.should == '12345'
    end
    it "should be nil if there is no indication of catkey in identityMetadata even if there is a catkey in the mods" do
      m = "<mods #{@ns_decl}><recordInfo>
        <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
      </recordInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.stub(:public_xml).and_return(@empty_id_md_ng.root)
      sdb.catkey.should == nil
    end
    it "should log an error when there is identityMetadata/otherId with name attribute of barcode but there is no catkey in mods" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}> </mods>"))
      logger = Logger.new(@strio)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, logger)
      sdb.stub(:public_xml).and_return(@barcode_id_md_ng.root)
      logger.should_receive(:error).with(/#{@fake_druid} has barcode .* in identityMetadata but no SIRSI catkey in mods/)
      sdb.catkey
    end
    context "catkey from mods" do
      it "should look for catkey in mods if identityMetadata/otherId with name attribute of barcode is found" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}> </mods>"))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:public_xml).and_return(@barcode_id_md_ng.root)
        smr = sdb.smods_rec
        smr.should_receive(:record_info).and_call_original # this is as close as I can figure to @smods_rec.record_info.recordIdentifier
        sdb.catkey
      end
      it 'should be nil if there is no catkey in the mods' do
        m = "<mods #{@ns_decl}><recordInfo>
          <descriptionStandard>dacs</descriptionStandard>
        </recordInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:public_xml).and_return(@barcode_id_md_ng.root)
        sdb.catkey.should == nil
      end
      it "populated when source attribute is SIRSI" do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:public_xml).and_return(@barcode_id_md_ng.root)
        sdb.catkey.should_not == nil
      end
      it "not populated when source attribute is not SIRSI" do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"FOO\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:public_xml).and_return(@barcode_id_md_ng.root)
        sdb.catkey.should == nil
      end
      it "should remove the a at the beginning of the catkey" do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:public_xml).and_return(@barcode_id_md_ng.root)
        sdb.catkey.should == '6780453'
      end
    end
  end # catkey

  context "using Harvestdor::Client" do
    before(:all) do
      config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
      solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
      @indexer = Indexer.new(config_yml_path, solr_yml_path)
      @real_hdor_client = @indexer.send(:harvestdor_client)
    end
    
    context "smods_rec method (called in initialize method)" do
      it "should return Stanford::Mods::Record object" do
        @real_hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @real_hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
        sdb = SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil)
        sdb.smods_rec.should be_an_instance_of(Stanford::Mods::Record)
      end
      it "should raise exception if MODS xml for the druid is empty" do
        @real_hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}/>"))
        expect { SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil) }.to raise_error(RuntimeError, Regexp.new("^Empty MODS metadata for #{@fake_druid}: <"))
      end
      it "should raise exception if there is no MODS xml for the druid" do
        expect { SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil) }.to raise_error(Harvestdor::Errors::MissingMods)
      end
    end

    context "public_xml method (called in initialize method)" do
      before(:each) do
        @real_hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      end
      it "should call public_xml method on harvestdor_client" do
        @real_hdor_client.should_receive(:public_xml).with(@fake_druid)
        sdb = SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil)
      end
      it "should raise exception if there is no contentMetadata for the druid" do
        expect { SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil) }.to raise_error(Harvestdor::Errors::MissingPurlPage)
      end
    end
  end # context using Harvestdor::Client

end