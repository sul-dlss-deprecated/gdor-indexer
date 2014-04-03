require 'spec_helper'

describe 'public_xml_fields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>")
    @empty_ng_pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'></publicObject>")
  end
    
  # NOTE:  
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope
  
  context "identityMetadata fields and methods" do
    before(:all) do
      @id_md_xml = "<identityMetadata><objectId>druid:#{@fake_druid}</objectId></identityMetadata>"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@id_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end
    before(:each) do
      @hdor_client = double
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end
    context "identity_md" do
      it "identity_md should get the identityMetadata from public_xml, not a separate fetch" do
        @hdor_client.should_not_receive(:identity_metadata)
        @sdb.should_receive(:public_xml).and_call_original
        identity_md = @sdb.send(:identity_md)
        identity_md.should be_an_instance_of(Nokogiri::XML::Element)
        identity_md.name.should == 'identityMetadata'
# NOTE:  the below isn't working -- probably due to Nokogiri bug with attributes
#        identity_md.should be_equivalent_to(@id_md_xml)
      end
      it "should log an error message if there is no identityMetadata" do
        @sdb.should_receive(:public_xml).and_return(@empty_ng_pub_xml)
        @sdb.logger.should_receive(:error).with("#{@fake_druid} missing identityMetadata")
        @sdb.send(:identity_md)
      end
    end
    
    context "coll_object?" do
      it "should return true if identityMetadata has objectType element with value 'collection'" do
        id_md_xml = "<identityMetadata><objectType>collection</objectType></identityMetadata>"
        ng_pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{id_md_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(ng_pub_xml)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        @sdb.coll_object?.should == true
      end
      it "should return false if identityMetadata has objectType element with value other than 'collection'" do
        id_md_xml = "<identityMetadata><objectType>other</objectType></identityMetadata>"
        ng_pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{id_md_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(ng_pub_xml)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        @sdb.coll_object?.should == false
      end
      it "should return false if identityMetadata doesn't have an objectType" do
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        @sdb.coll_object?.should == false
      end
    end
  end # identityMetadata fields and methods
  
  context "contentMetadata fields and methods" do
    before(:all) do
      @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
      @content_md_end = "</contentMetadata>"
      @cntnt_md_type = 'image'
      @cntnt_md_xml = "<contentMetadata type='#{@cntnt_md_type}' objectId='#{@fake_druid}'>#{@content_md_end}"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@cntnt_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end
    before(:each) do
      @hdor_client = double
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end

    context "content_md" do
      it "content_md should get the contentMetadata from public_xml, not a separate fetch" do
        @hdor_client.should_not_receive(:content_metadata)
        @sdb.should_receive(:public_xml).and_call_original
        content_md = @sdb.send(:content_md)
        content_md.should be_an_instance_of(Nokogiri::XML::Element)
        content_md.name.should == 'contentMetadata'
# NOTE:  the below isn't working -- probably due to Nokogiri bug with attributes
#        content_md.should be_equivalent_to(@cntnt_md_xml)
      end
      it "should log an error message if there is no contentMetadata" do
        @sdb.should_receive(:public_xml).and_return(@empty_ng_pub_xml)
        @sdb.logger.should_receive(:error).with("#{@fake_druid} missing contentMetadata")
        @sdb.send(:content_md)
      end
    end

    context "dor_content_type" do
      it "should be retreived from the <contentMetadata>" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:content_md)
        sdb.dor_content_type
      end
      it "should be the value of the type attribute on <contentMetadata> element" do
        val = 'foo'
        cntnt_md_xml = "<contentMetadata type='#{val}'>#{@content_md_end}"
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:content_md).at_least(1).times.and_return(Nokogiri::XML(cntnt_md_xml).root)
        sdb.dor_content_type.should == val
      end
    end
    
    context "display_type" do
      it "should not access the mods to determine the display_type" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        @hdor_client.should_not_receive(:mods).with(@fake_druid)
        sdb.should_receive(:coll_object?).and_return(false)
        sdb.display_type
      end
      it "should be 'collection' if coll_object? and no add_display_type" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:coll_object?).and_return(true)
        sdb.display_type.should == 'collection'
      end
      it "should be the value of dor_content_type if not coll_object?" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:coll_object?).and_return(false)
        sdb.stub(:dor_content_type).and_return('bogus')
        sdb.display_type.should == 'bogus'
      end
      it "should be hydrus_collection for config :add_display_type of 'hydrus' and coll_object?" do
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:coll_object?).and_return(true)
        sdb.display_type.should == 'hydrus_collection'
      end
      it "should be hydrus_object for config :add_display_type of 'hydrus' and not coll_object?" do
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:coll_object?).and_return(false)
        sdb.display_type.should == 'hydrus_object'
      end
      it "should log an error message if dor_content_type is nil" do
        @sdb.stub(:dor_content_type).and_return(nil)
        @sdb.logger.should_receive(:error).with("#{@fake_druid} has no DOR content type (<contentMetadata> element may be missing type attribute)")
        @sdb.should_receive(:coll_object?).and_return(false)
        @sdb.display_type
      end
    end # display_type
    
    context "image_ids" do
      before(:each) do
        @hdor_client = double
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
      end
      it "should be nil if there are no <resource> elements in the contentMetadata" do
        ng_xml = Nokogiri::XML("#{@content_md_start}#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should ignore <resource> elements with attribute type other than 'image' or 'page'" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='blarg'><file id='foo'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      
      # Addresses GRYPHONDOR-313: image resources from book pages not appearing in searchworks
      it "should not ignore <resource> elements with attribute type of 'page'" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type=\"page\" sequence=\"1\" id=\"ft092fb6660_1\">
            <label>Image 1</label>
            <file id=\"ft092fb6660_00_0001.jp2\" mimetype=\"image/jp2\" size=\"1884208\" preserve=\"no\" publish=\"yes\" shelve=\"yes\">
              <imageData width=\"3184\" height=\"3122\"/>
            </file>
          </resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['ft092fb6660_00_0001']
      end
      it "should only include image links for jp2s" do
        dh051qf2834_page_resource = '<resource type="page" sequence="1" id="dh051qf2834_1">
            <label>Image 1</label>
            <file id="dh051qf2834_00_0001.jpg" mimetype="image/jpeg" size="1669550" preserve="yes" publish="no" shelve="no">
              <checksum type="md5">dc725c103de7ac9e4da9a0b93f1127d2</checksum>
              <checksum type="sha1">6a54da77d2196ce763c89f1a91e7df2f38196db0</checksum>
              <imageData width="2370" height="3280"/>
            </file>
            <file id="dh051qf2834_04_0001.xml" mimetype="application/xml" size="9266" preserve="yes" publish="no" shelve="no">
              <checksum type="md5">20f20a5802a819b0a704dd9f96378d19</checksum>
              <checksum type="sha1">d666f254961a07eda5c6bda62a380efdc7cdce7a</checksum>
            </file>
            <file id="dh051qf2834_06_0001.pdf" mimetype="application/pdf" size="97507" preserve="yes" publish="yes" shelve="yes">
              <checksum type="md5">c68c4469d27eec11efe5c226f8cf3618</checksum>
              <checksum type="sha1">469fef84eddc9d02eb2774ff1f8f397e7605f11d</checksum>
            </file>
            <file id="dh051qf2834_00_0001.jp2" mimetype="image/jp2" size="1470534" preserve="no" publish="yes" shelve="yes">
              <checksum type="md5">8bc3568fe35ec2d8c0cd3e9420a7ce56</checksum>
              <checksum type="sha1">def4e03b88aaeefea362789f0ca38fc10467f7f3</checksum>
              <imageData width="2370" height="3280"/>
            </file>
          </resource>'
          ng_xml = Nokogiri::XML("#{@content_md_start}#{dh051qf2834_page_resource}#{@content_md_end}")
          @sdb.stub(:content_md).and_return(ng_xml.root)
          @sdb.image_ids.should == ['dh051qf2834_00_0001']
      end
      
      it "should be ignore all but <file> element children of the image resource element" do
        ng_xml = ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><label id='foo'>bar</label></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should be nil if there are no id elements on file elements" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == nil
      end
      it "should be an Array of size one if there is a single <resource><file id='something' mimetype='image/jp2'> in the content metadata" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='foo' mimetype='image/jp2'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['foo']
      end
      it "should be the same size as the number of <resource><file id='something'> in the content metadata" do
        ng_xml = Nokogiri::XML("#{@content_md_start}
              <resource type='image'><file id='foo' mimetype='image/jp2'/></resource>
              <resource type='image'><file id='bar' mimetype='image/jp2'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['foo', 'bar']
      end
      it "endings of .jp2 should be stripped" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file id='W188_000001_300.jp2' mimetype='image/jp2'/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.image_ids.should == ['W188_000001_300']
      end
    end # image_ids
    
  end # contentMetadata fields and methods
  
  context "rels-ext fields and methods" do
    before(:each) do
      @hdor_client = double
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @ns_decl = "xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'"
    end
    context "coll_druids_from_rels_ext" do
      it "should get the rels_ext from public_xml, not a separate fetch" do
        rels_ext_xml = "<rdf:RDF #{@ns_decl}>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'></rdf:Description></rdf:RDF>"
        pub_xml_ng = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.should_receive(:public_xml).and_return(pub_xml_ng)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        @hdor_client.should_not_receive(:rels_ext)
        @sdb.should_receive(:public_xml).and_return(pub_xml_ng)
        @sdb.coll_druids_from_rels_ext
      end
      it "coll_druids_from_rels_ext look for the object's collection druids in the rels-ext in the public_xml" do
        coll_druid = 'ww121ss5000'
        rels_ext_xml = "<rdf:RDF #{@ns_decl}>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid}'/>
          </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(pub_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.coll_druids_from_rels_ext.should == [coll_druid]
      end
      it "coll_druids_from_rels_ext should get multiple collection druids when they exist" do
        coll_druid = 'ww121ss5000'
        coll_druid2 = 'ww121ss5001'
        rels_ext_xml = "<rdf:RDF #{@ns_decl}>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid}'/>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid2}'/>
          </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(pub_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.coll_druids_from_rels_ext.should == [coll_druid, coll_druid2]
      end
      it "coll_druids_from_rels_ext should be nil when no isMemberOf relationships exist" do
        coll_druid = 'ww121ss5000'
        rels_ext_xml = "<rdf:RDF #{@ns_decl}>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
          </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(pub_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.coll_druids_from_rels_ext.should == nil
      end
    end # collection druids    
  end # rels-ext fields and methods
  
end