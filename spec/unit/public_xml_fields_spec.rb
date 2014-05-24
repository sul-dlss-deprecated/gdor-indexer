require 'spec_helper'

describe 'public_xml_fields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>public_xml_fields tests</note></mods>")
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
        @sdb.should_receive(:content_md)
        @sdb.dor_content_type
      end
      it "should be the value of the type attribute on <contentMetadata> element" do
        val = 'foo'
        cntnt_md_xml = "<contentMetadata type='#{val}'>#{@content_md_end}"
        @sdb.should_receive(:content_md).at_least(1).times.and_return(Nokogiri::XML(cntnt_md_xml).root)
        @sdb.dor_content_type.should == val
      end
      it "should log an error message if there is no content type" do
        cntnt_md_xml = "#{@content_md_start}#{@content_md_end}"
        @sdb.should_receive(:content_md).at_least(1).times.and_return(Nokogiri::XML(cntnt_md_xml).root)
        @sdb.logger.should_receive(:error).with("#{@fake_druid} has no DOR content type (<contentMetadata> element may be missing type attribute)")
        @sdb.dor_content_type
      end
    end
    
    context "display_type" do
      it "should not access the mods to determine the display_type" do
        @hdor_client.should_not_receive(:mods).with(@fake_druid)
        @sdb.display_type
      end
      it "'image' for dor_content_type 'image'" do
        @sdb.stub(:dor_content_type).and_return('image')
        @sdb.display_type.should == 'image'
      end
      it "'image' for dor_content_type 'manuscript'" do
        @sdb.stub(:dor_content_type).and_return('manuscript')
        @sdb.display_type.should == 'image'
      end
      it "'image' for dor_content_type 'map'" do
        @sdb.stub(:dor_content_type).and_return('map')
        @sdb.display_type.should == 'image'
      end
      it "'file' for dor_content_type 'media'" do
        @sdb.stub(:dor_content_type).and_return('media')
        @sdb.display_type.should == 'file'
      end
      it "'book' for dor_content_type 'book'" do
        @sdb.stub(:dor_content_type).and_return('book')
        @sdb.display_type.should == 'book'
      end
      it "'file' for unrecognized dor_content_type" do
        @sdb.stub(:dor_content_type).and_return('foo')
        @sdb.display_type.should == 'file'
      end
      it "should not be hydrus_xxx for config :add_display_type of 'hydrus'" do
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        @sdb.display_type.should_not =~ /^hydrus/
      end
    end # display_type
    
    context "#file_ids" do
      before(:each) do
        @hdor_client = double
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
        @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
      end
      context "file display_type" do
        context "contentMetadata type=file, resource type=file" do
          it "should be id attrib of file element in single resource element with type=file" do
            ng_xml = Nokogiri::XML('<contentMetadata type="file" objectId="xh812jt9999">
              <resource type="file" sequence="1" id="xh812jt9999_1">
                <label>John A. Blume Earthquake Engineering Center Technical Report 180</label>
                <file id="TR180_Shahi.pdf" mimetype="application/pdf" size="4949212" />
              </resource></contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == ['TR180_Shahi.pdf']
          end
          it "should be id attrib of file elements in multiple resource elements with type=file" do
            ng_xml = Nokogiri::XML('<contentMetadata objectId="jt108hm9275" type="file">
              <resource id="jt108hm9275_1" sequence="1" type="file">
               <label>Access to Energy newsletter, 1973-1994</label>
               <file id="ATE.PDF" mimetype="application/pdf" size="16297305" />
              </resource>
              <resource id="jt108hm9275_8" sequence="8" type="file">
               <label>Computer Forum Festschrift for Edward Feigenbaum, 2006 (part 6)</label>
               <file id="SC0524_2013-047_b8_811.mp4" mimetype="video/mp4" size="860912776" />
              </resource>
              <resource id="jt108hm9275_9" sequence="9" type="file">
                <label>Stanford AI Lab (SAILDART) files</label>
                <file id="SAILDART.zip" mimetype="application/zip" size="472230479" />
              </resource>
              <resource id="jt108hm9275_10" sequence="10" type="file">
                <label>WTDS Interview: Douglas C. Engelbart, 2006 Apr 13</label>
                <file id="DougEngelbart041306.wav" mimetype="audio/x-wav" size="273705910" />
              </resource></contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == ['ATE.PDF', "SC0524_2013-047_b8_811.mp4", "SAILDART.zip", "DougEngelbart041306.wav"]
          end
        end # contentMetadata type=file, resource type=file
        it "contentMetadata type=geo, resource type=object" do
          ng_xml = Nokogiri::XML('<contentMetadata objectId="druid:qk786js7484" type="geo">
            <resource id="druid:qk786js7484_1" sequence="1" type="object">
              <label>Data</label>
              <file id="data.zip" mimetype="application/zip" role="master" size="10776648" />
            </resource>
            <resource id="druid:qk786js7484_2" sequence="2" type="preview">
              <label>Preview</label>
              <file id="preview.jpg" mimetype="image/jpeg" role="master" size="140661">
                <imageData height="846" width="919"/>
              </file>
            </resource></contentMetadata>')
          @sdb.stub(:content_md).and_return(ng_xml.root)
          @sdb.file_ids.should == ['data.zip', 'preview.jpg']
        end
        
        # FIXME:  non-file resource types
        
      end # file display_type
      context "image display_type" do
        context "contentMetadata type=image" do
          it "resource type=image should be id attrib of file elements" do
            ng_xml = Nokogiri::XML('<contentMetadata objectId="rg759wj0953" type="image">
              <resource id="rg759wj0953_1" sequence="1" type="image">
                <label>Image 1</label>
                <file id="rg759wj0953_00_0003.jp2" mimetype="image/jp2" size="13248250">
                  <imageData width="6254" height="11236"/>
                </file>
              </resource>
              <resource id="rg759wj0953_2" sequence="2" type="image">
                <label>Image 2</label>
                <file id="rg759wj0953_00_00_0001.jp2" mimetype="image/jp2" size="8484503">
                  <imageData width="7266" height="6188"/>
                </file>
              </resource></contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == ['rg759wj0953_00_0003.jp2', 'rg759wj0953_00_00_0001.jp2']
          end
          it "resource type=object should be ignored" do
            ng_xml = Nokogiri::XML('<contentMetadata objectId="ny981gz0831" type="image">
              <resource id="ny981gz0831_1" sequence="1" type="object">
                <label>File 1</label>
                <file id="da39a3ee5e6b4b0d3255bfef95601890afd80709.dderr" mimetype="application/x-symlink" size="26634" />
                <file id="da39a3ee5e6b4b0d3255bfef95601890afd80709.img" mimetype="application/x-symlink" size="368640" />
                <file id="da39a3ee5e6b4b0d3255bfef95601890afd80709.img.sha" mimetype="application/x-symlink" size="173" />
              </resource></contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == nil
          end
        end # contentMetadata type=image
        context "contentMetadata type=map, resource type=image" do
          it "should be id attrib of file elements" do
            ng_xml = Nokogiri::XML('<contentMetadata objectId="druid:rf935xg1061" type="map">
              <resource id="0001" sequence="1" type="image">
                <file id="rf935xg1061_00_0001.jp2" mimetype="image/jp2" size="20204910">
                  <imageData height="7248" width="14787"/>
                </file>
              </resource>
              <resource id="0002" sequence="2" type="image">
                <file id="rf935xg1061_00_0002.jp2" mimetype="image/jp2" size="20209446">
                  <imageData height="7248" width="14787"/>
                </file>
              </resource></contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == ['rf935xg1061_00_0001.jp2', 'rf935xg1061_00_0002.jp2']
          end
        end # contentMetadata type=map, resource type=image
        context "contentMetadata type=manuscript" do
          it "resource type=image" do
            ng_xml = Nokogiri::XML('<contentMetadata objectId="druid:my191bb7431" type="manuscript">
              <resource id="manuscript-image-1" sequence="1" type="image">
                <label>Front Outer Board</label>
                <file format="JPEG2000" id="T0000001.jp2" mimetype="image/jp2" size="7553958">
                   <imageData height="4578" width="3442"/>
                </file>
              </resource>
              <resource id="manuscript-image-343" sequence="343" type="image">
                  <label>Spine</label>
                  <file format="JPEG2000" id="T0000343.jp2" mimetype="image/jp2" size="1929355">
                    <imageData height="4611" width="986"/>
                  </file>
                </resource>
              </contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == ['T0000001.jp2', 'T0000343.jp2']
          end
          it "resource type=page should be ignored" do
            ng_xml = Nokogiri::XML('<contentMetadata objectId="druid:Bodley342" type="manuscript">
              <resource type="page" sequence="1" id="image-1">
                <label>1</label>
                <file mimetype="image/jp2" format="JPEG2000" size="1319924" id="asn0001-M.jp2">
                  <imageData height="3466" width="2405"/>
                </file>
              </resource>
              <resource type="page" sequence="453" id="image-453">
                <label>453</label>
                <file mimetype="image/jp2" format="JPEG2000" size="1457066" id="asn0452-M.jp2">
                  <imageData height="3431" width="2431"/>
                </file>
              </resource></contentMetadata>')
            @sdb.stub(:content_md).and_return(ng_xml.root)
            @sdb.file_ids.should == nil
          end
        end # contentMetadata type=manuscript
      end # image display_type

      it "should be nil for book display_type" do
        ng_xml = Nokogiri::XML('<contentMetadata type="book" objectId="xm901jg3836">
          <resource type="image" sequence="1" id="xm901jg3836_1">
            <label>Item 1</label>
            <file id="xm901jg3836_00_0002.jp2" mimetype="image/jp2" size="1152852">
              <imageData width="2091" height="2905"/>
            </file>
          </resource>
          <resource type="image" sequence="608" id="xm901jg3836_608">
            <label>Item 608</label>
            <file id="xm901jg3836_00_0609.jp2" mimetype="image/jp2" size="1152297">
              <imageData width="2090" height="2905"/>
            </file>
          </resource></contentMetadata>')
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.file_ids.should == nil
      end
      it "should be id attrib of file elements for media display_type" do
        ng_xml = Nokogiri::XML('<contentMetadata objectId="jy496kh1727" type="media">
          <resource sequence="1" id="jy496kh1727_1" type="audio">
            <label>Tape 1, Pass 1</label>
            <file id="jy496kh1727_sl.mp3" mimetype="audio/mpeg" size="57010677" />
          </resource>
          <resource sequence="2" id="jy496kh1727_2" type="image">
            <label>Image of media (1 of 3)</label>
            <file id="jy496kh1727_img_1.jp2" mimetype="image/jp2" size="1277821">
              <imageData width="2659" height="2535"/>
            </file>
          </resource></contentMetadata>')
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.file_ids.should == ["jy496kh1727_sl.mp3", "jy496kh1727_img_1.jp2"]
      end
      it "should be nil if there are no <resource> elements in the contentMetadata" do
        ng_xml = Nokogiri::XML('<contentMetadata objectId="jy496kh1727" type="file"></contentMetadata>')
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.file_ids.should == nil
      end
      it "should be nil if there are no <file> elements in the contentMetadata" do
        ng_xml = Nokogiri::XML('<contentMetadata objectId="jy496kh1727" type="file">
          <resource sequence="1" id="jy496kh1727_1" type="file">
            <label>Tape 1, Pass 1</label>
          </resource>
          <resource sequence="2" id="jy496kh1727_2" type="image">
            <label>Image of media (1 of 3)</label>
          </resource></contentMetadata>')
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.file_ids.should == nil
      end
      it "should be nil if there are no id elements on file elements" do
        ng_xml = Nokogiri::XML("#{@content_md_start}<resource type='image'><file/></resource>#{@content_md_end}")
        @sdb.stub(:content_md).and_return(ng_xml.root)
        @sdb.file_ids.should == nil
      end

      # TODO:  multiple file elements in a single resource element

    end # file_ids
    
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