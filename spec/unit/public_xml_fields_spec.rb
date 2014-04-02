require 'spec_helper'

describe 'public_xml_fields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>")
  end
    
  # NOTE:  
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope
  
  context "fields from and methods pertaining to contentMetadata" do
    before(:all) do
      @cntnt_md_type = 'image'
      @cntnt_md_xml = "<contentMetadata type='#{@cntnt_md_type}' objectId='#{@fake_druid}'></contentMetadata>"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@cntnt_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end

    it "content_md should get the contentMetadata from public_xml, not a separate fetch" do
      @hdor_client.should_not_receive(:content_metadata)
      @sdb.should_receive(:public_xml).and_call_original
      content_md = @sdb.send(:content_md)
      content_md.should be_an_instance_of(Nokogiri::XML::Element)
      content_md.name.should == 'contentMetadata'
# NOTE:  the below isn't working -- probably due to Nokogiri attribute bug introduced      
#      content_md.should be_equivalent_to(@cntnt_md_xml)
    end
    
    context "display_type" do
      it "should be 'collection' if solr_doc_builder.collection?" do
        coll_mods_xml = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>hi</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(coll_mods_xml))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.display_type.should == 'collection'
      end
      it "should be 'hydrus_collection' if it is a collection and :display_type=hydrus is in the collection yml file" do
        coll_mods_xml = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>hi</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(coll_mods_xml))
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.display_type.should == 'hydrus_collection'
      end
      it "should be 'hydrus_object' if it is not a collection and :display_type=hydrus is in the collection yml file" do
        coll_mods_xml = "<mods #{@ns_decl}><typeOfResource/><note>hi</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(coll_mods_xml))
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.display_type.should == 'hydrus_object'
      end
      it "should be the same as <contentMetadata> type attribute if it's not a collection" do
        # NOTE: from the contentMetadata, not the mods
        m = "<mods #{@ns_decl}><typeOfResource>sound recording</typeOfResource></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.display_type.should == @cntnt_md_type
        sdb.stub(:dor_content_type).and_return('bogus')
        sdb.display_type.should == 'bogus'
      end
      it "should log an error message if contentMetadata has no type" do
        @sdb.stub(:dor_content_type).and_return(nil)
        @sdb.logger.should_receive(:warn).with(/has no DOR content type/)
        @sdb.display_type
      end
      
      it "should be hydrus_collection for config :add_display_type of 'hydrus' and collection object" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:collection?).and_return(true)
        sdb.display_type.should eql("hydrus_collection")
      end
      it "should be hydrus_object for config :add_display_type of 'hydrus' and member object" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:collection?).and_return(false)
        sdb.display_type.should eql("hydrus_object")      
      end
    end # display_ytype
    
    context "image_ids" do
      before(:all) do
        @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
        @content_md_end = "</contentMetadata>"
      end
      before(:each) do
        @hdor_client = double()
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
    end
    
  end # fields from and methods pertaining to contentMetadata
  
  context "fields from and methods pertaining to rels-ext" do
    before(:each) do
      @hdor_client = double()
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
  end # fields from and methods pertaining to rels-ext
  
end