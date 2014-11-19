require 'spec_helper'

describe GDor::Indexer::SolrDocBuilder do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>SolrDocBuilder test</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
    @strio = StringIO.new
  end

  # NOTE:
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope

  context "doc_hash" do
    before(:all) do
      cmd_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'></contentMetadata>"
      @ng_pub_xml = Nokogiri::XML("<publicObject id='druid#{@fake_druid}'>#{cmd_xml}</publicObject>")
    end
    before(:each) do
      @hdor_client = double
      allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      allow(@hdor_client).to receive(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @doc_hash = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash
    end
    it "id field should be set to druid for non-merged record" do
      expect(@doc_hash[:id]).to eq(@fake_druid)
    end
    it "should not have the gdor fields set in indexer.rb" do
      expect(@doc_hash).to_not have_key(:druid)
      expect(@doc_hash).to_not have_key(:access_facet)
      expect(@doc_hash).to_not have_key(:url_fulltext)
      expect(@doc_hash).to_not have_key(:display_type)
      expect(@doc_hash).to_not have_key(:file_id)
    end
    it "should have the full MODS in the modsxml field for non-merged record" do
      # this fails with equivalent-xml 0.4.1 or 0.4.2, but passes with 0.4.0
      expect(@doc_hash[:modsxml]).to be_equivalent_to @mods_xml
    end 
    it "should call doc_hash_from_mods to populate hash fields from MODS" do
      sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      expect(sdb).to receive(:doc_hash_from_mods)
      sdb.doc_hash
    end
  end # doc hash

  context '#catkey' do
    before(:all) do
      @identity_md_start = "<publicObject><identityMetadata objectId='#{@fake_druid}'>"
      @identity_md_end = "</identityMetadata></publicObject>"
      @empty_id_md_ng = Nokogiri::XML("#{@identity_md_start}#{@identity_md_end}")
      @barcode_id_md_ng = Nokogiri::XML("#{@identity_md_start}<otherId name=\"barcode\">666</otherId>#{@identity_md_end}")
    end
    before(:each) do
      @hdor_client = double
      allow(@hdor_client).to receive(:public_xml).with(@fake_druid).and_return(nil)
      allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
    end
    
    it "should be nil if there is no indication of catkey in identityMetadata" do
      allow(@sdb).to receive(:public_xml).and_return(@empty_id_md_ng.root)
      expect(@sdb.catkey).to be_nil
    end
    it "should take a catkey in identityMetadata/otherId with name attribute of catkey" do
      ng_xml = Nokogiri::XML("#{@identity_md_start}<otherId name=\"catkey\">12345</otherId>#{@identity_md_end}")
      allow(@sdb).to receive(:public_xml).and_return(ng_xml.root)
      expect(@sdb.catkey).to eq('12345')
    end
    it "should be nil if there is no indication of catkey in identityMetadata even if there is a catkey in the mods" do
      m = "<mods #{@ns_decl}><recordInfo>
        <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
      </recordInfo></mods>"
      allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      allow(sdb).to receive(:public_xml).and_return(@empty_id_md_ng.root)
      expect(sdb.catkey).to be_nil
    end
    it "should log an error when there is identityMetadata/otherId with name attribute of barcode but there is no catkey in mods" do
      allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      logger = Logger.new(@strio)
      sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, logger)
      allow(sdb).to receive(:public_xml).and_return(@barcode_id_md_ng.root)
      expect(logger).to receive(:error).with(/#{@fake_druid} has barcode .* in identityMetadata but no SIRSI catkey in mods/)
      sdb.catkey
    end
    
    context "catkey from mods" do
      it "should look for catkey in mods if identityMetadata/otherId with name attribute of barcode is found" do
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        allow(sdb).to receive(:public_xml).and_return(@barcode_id_md_ng.root)
        smr = sdb.smods_rec
        expect(smr).to receive(:record_info).and_call_original # this is as close as I can figure to @smods_rec.record_info.recordIdentifier
        sdb.catkey
      end
      it 'should be nil if there is no catkey in the mods' do
        m = "<mods #{@ns_decl}><recordInfo>
          <descriptionStandard>dacs</descriptionStandard>
        </recordInfo></mods>"
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        allow(sdb).to receive(:public_xml).and_return(@barcode_id_md_ng.root)
        expect(sdb.catkey).to be_nil
      end
      it "populated when source attribute is SIRSI" do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        allow(sdb).to receive(:public_xml).and_return(@barcode_id_md_ng.root)
        expect(sdb.catkey).not_to be_nil
      end
      it "not populated when source attribute is not SIRSI" do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"FOO\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        allow(sdb).to receive(:public_xml).and_return(@barcode_id_md_ng.root)
        expect(sdb.catkey).to be_nil
      end
      it "should remove the a at the beginning of the catkey" do
        m = "<mods #{@ns_decl}><recordInfo>
          <recordIdentifier source=\"SIRSI\">a6780453</recordIdentifier>
        </recordInfo></mods>"
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        allow(sdb).to receive(:public_xml).and_return(@barcode_id_md_ng.root)
        expect(sdb.catkey).to eq('6780453')
      end
    end
  end # #catkey

  context "using Harvestdor::Client" do
    before(:all) do
      config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
      solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
      client_config_path = File.join(File.dirname(__FILE__), "..", "config", "dor-fetcher-client.yml")
      @indexer = GDor::Indexer.new(config_yml_path, client_config_path, solr_yml_path)
      @real_hdor_client = @indexer.send(:harvestdor_client)
    end
    
    context "#smods_rec (called in initialize method)" do
      it "should return Stanford::Mods::Record object" do
        allow(@real_hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        allow(@real_hdor_client).to receive(:public_xml).with(@fake_druid).and_return(nil)
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil)
        expect(sdb.smods_rec).to be_an_instance_of(Stanford::Mods::Record)
      end
      it "should raise exception if MODS xml for the druid is empty" do
        allow(@real_hdor_client).to receive(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}/>"))
        expect { GDor::Indexer::SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil) }.to raise_error(RuntimeError, Regexp.new("^Empty MODS metadata for #{@fake_druid}: <"))
      end
      it "should raise exception if there is no MODS xml for the druid" do
        expect { GDor::Indexer::SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil) }.to raise_error(Harvestdor::Errors::MissingMods)
      end
    end

    context "#public_xml (called in initialize method)" do
      before(:each) do
        allow(@real_hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      end
      it "should call public_xml method on harvestdor_client" do
        expect(@real_hdor_client).to receive(:public_xml).with(@fake_druid)
        sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil)
      end
      it "should raise exception if there is no contentMetadata for the druid" do
        expect { GDor::Indexer::SolrDocBuilder.new(@fake_druid, @real_hdor_client, nil) }.to raise_error(Harvestdor::Errors::MissingPurlPage)
      end
    end
  end # context using Harvestdor::Client

end