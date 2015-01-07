require 'spec_helper'

describe GDor::Indexer::PublicXmlFields do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>public_xml_fields tests</note></mods>"
    @empty_pub_xml = "<publicObject id='druid:#{@fake_druid}'></publicObject>"
  end

  let :logger do
    Logger.new(StringIO.new)
  end

  def sdb_for_pub_xml m
    resource = Harvestdor::Indexer::Resource.new(double, @fake_druid)
    allow(resource).to receive(:public_xml).and_return(Nokogiri::XML(m))
    allow(resource).to receive(:mods).and_return(@mods_xml)
    GDor::Indexer::SolrDocBuilder.new(resource, logger)
  end
  def sdb_for_content_md m
    resource = Harvestdor::Indexer::Resource.new(double, @fake_druid)
    allow(resource).to receive(:content_metadata).and_return(Nokogiri::XML(m).root)
    allow(resource).to receive(:public_xml).and_return(@empty_pub_xml)
    allow(resource).to receive(:mods).and_return(@mods_xml)
    GDor::Indexer::SolrDocBuilder.new(resource, logger)
  end
  
    
  # NOTE:  
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope
  
  
  context "contentMetadata fields and methods" do
    before(:all) do
      @content_md_start = "<contentMetadata objectId='#{@fake_druid}'>"
      @content_md_end = "</contentMetadata>"
      @cntnt_md_type = 'image'
      @cntnt_md_xml = "<contentMetadata type='#{@cntnt_md_type}' objectId='#{@fake_druid}'>#{@content_md_end}"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@cntnt_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end

    context "dor_content_type" do
      it "should be the value of the type attribute on <contentMetadata> element" do
        val = 'foo'
        cntnt_md = "<contentMetadata type='#{val}'>#{@content_md_end}"
        sdb = sdb_for_content_md(cntnt_md)
        expect(sdb.send(:dor_content_type)).to eq(val)
      end
      it "should log an error message if there is no content type" do
        cntnt_md = "#{@content_md_start}#{@content_md_end}"
        sdb = sdb_for_content_md(cntnt_md)
        expect(sdb.logger).to receive(:error).with("#{@fake_druid} has no DOR content type (<contentMetadata> element may be missing type attribute)")
        sdb.send(:dor_content_type)
      end
    end
    
    context "display_type" do
      let :sdb do
        sdb_for_pub_xml @empty_pub_xml
      end

      it "'image' for dor_content_type 'image'" do
        allow(sdb).to receive(:dor_content_type).and_return('image')
        expect(sdb.display_type).to eq('image')
      end
      it "'image' for dor_content_type 'manuscript'" do
        allow(sdb).to receive(:dor_content_type).and_return('manuscript')
        expect(sdb.display_type).to eq('image')
      end
      it "'image' for dor_content_type 'map'" do
        allow(sdb).to receive(:dor_content_type).and_return('map')
        expect(sdb.display_type).to eq('image')
      end
      it "'file' for dor_content_type 'media'" do
        allow(sdb).to receive(:dor_content_type).and_return('media')
        expect(sdb.display_type).to eq('file')
      end
      it "'book' for dor_content_type 'book'" do
        allow(sdb).to receive(:dor_content_type).and_return('book')
        expect(sdb.display_type).to eq('book')
      end
      it "'file' for unrecognized dor_content_type" do
        allow(sdb).to receive(:dor_content_type).and_return('foo')
        expect(sdb.display_type).to eq('file')
      end
    end # display_type
    
    context "#file_ids" do
      context "file display_type" do
        context "contentMetadata type=file, resource type=file" do
          it "should be id attrib of file element in single resource element with type=file" do
            m = '<contentMetadata type="file" objectId="xh812jt9999">
              <resource type="file" sequence="1" id="xh812jt9999_1">
                <label>John A. Blume Earthquake Engineering Center Technical Report 180</label>
                <file id="TR180_Shahi.pdf" mimetype="application/pdf" size="4949212" />
              </resource></contentMetadata>'
            sdb = sdb_for_content_md(m)
            expect(sdb.file_ids).to match_array ['TR180_Shahi.pdf']
          end
          it "should be id attrib of file elements in multiple resource elements with type=file" do
            m = '<contentMetadata objectId="jt108hm9275" type="file">
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
              </resource></contentMetadata>'
            sdb = sdb_for_content_md(m)
            expect(sdb.file_ids).to match_array ['ATE.PDF', "SC0524_2013-047_b8_811.mp4", "SAILDART.zip", "DougEngelbart041306.wav"]
          end
        end # contentMetadata type=file, resource type=file
        it "contentMetadata type=geo, resource type=object" do
          m = '<contentMetadata objectId="druid:qk786js7484" type="geo">
            <resource id="druid:qk786js7484_1" sequence="1" type="object">
              <label>Data</label>
              <file id="data.zip" mimetype="application/zip" role="master" size="10776648" />
            </resource>
            <resource id="druid:qk786js7484_2" sequence="2" type="preview">
              <label>Preview</label>
              <file id="preview.jpg" mimetype="image/jpeg" role="master" size="140661">
                <imageData height="846" width="919"/>
              </file>
            </resource></contentMetadata>'
          sdb = sdb_for_content_md(m)
          expect(sdb.file_ids).to match_array ['data.zip', 'preview.jpg']
        end
        
        # FIXME:  non-file resource types
        
      end # file display_type
      context "image display_type" do
        context "contentMetadata type=image" do
          it "resource type=image should be id attrib of file elements" do
            m = '<contentMetadata objectId="rg759wj0953" type="image">
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
              </resource></contentMetadata>'
            sdb = sdb_for_content_md m
            expect(sdb.file_ids).to match_array ['rg759wj0953_00_0003.jp2', 'rg759wj0953_00_00_0001.jp2']
          end
          it "resource type=object should be ignored" do
            m = '<contentMetadata objectId="ny981gz0831" type="image">
              <resource id="ny981gz0831_1" sequence="1" type="object">
                <label>File 1</label>
                <file id="da39a3ee5e6b4b0d3255bfef95601890afd80709.dderr" mimetype="application/x-symlink" size="26634" />
                <file id="da39a3ee5e6b4b0d3255bfef95601890afd80709.img" mimetype="application/x-symlink" size="368640" />
                <file id="da39a3ee5e6b4b0d3255bfef95601890afd80709.img.sha" mimetype="application/x-symlink" size="173" />
              </resource></contentMetadata>'
            sdb = sdb_for_content_md(m)
            expect(sdb.file_ids).to be_nil
          end
        end # contentMetadata type=image
        context "contentMetadata type=map, resource type=image" do
          it "should be id attrib of file elements" do
            m = '<contentMetadata objectId="druid:rf935xg1061" type="map">
              <resource id="0001" sequence="1" type="image">
                <file id="rf935xg1061_00_0001.jp2" mimetype="image/jp2" size="20204910">
                  <imageData height="7248" width="14787"/>
                </file>
              </resource>
              <resource id="0002" sequence="2" type="image">
                <file id="rf935xg1061_00_0002.jp2" mimetype="image/jp2" size="20209446">
                  <imageData height="7248" width="14787"/>
                </file>
              </resource></contentMetadata>'
            sdb = sdb_for_content_md(m)
            expect(sdb.file_ids).to match_array ['rf935xg1061_00_0001.jp2', 'rf935xg1061_00_0002.jp2']
          end
        end # contentMetadata type=map, resource type=image
        context "contentMetadata type=manuscript" do
          it "resource type=image" do
            m = '<contentMetadata objectId="druid:my191bb7431" type="manuscript">
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
              </contentMetadata>'
            sdb = sdb_for_content_md(m)
            expect(sdb.file_ids).to match_array ['T0000001.jp2', 'T0000343.jp2']
          end
          it "resource type=page should be ignored" do
            m = '<contentMetadata objectId="druid:Bodley342" type="manuscript">
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
              </resource></contentMetadata>'
            sdb = sdb_for_content_md(m)
            expect(sdb.file_ids).to be_nil
          end
        end # contentMetadata type=manuscript
      end # image display_type

      it "should be nil for book display_type" do
        m = '<contentMetadata type="book" objectId="xm901jg3836">
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
          </resource></contentMetadata>'
        sdb = sdb_for_content_md(m)
        expect(sdb.file_ids).to be_nil
      end
      it "should be id attrib of file elements for media display_type" do
        m = '<contentMetadata objectId="jy496kh1727" type="media">
          <resource sequence="1" id="jy496kh1727_1" type="audio">
            <label>Tape 1, Pass 1</label>
            <file id="jy496kh1727_sl.mp3" mimetype="audio/mpeg" size="57010677" />
          </resource>
          <resource sequence="2" id="jy496kh1727_2" type="image">
            <label>Image of media (1 of 3)</label>
            <file id="jy496kh1727_img_1.jp2" mimetype="image/jp2" size="1277821">
              <imageData width="2659" height="2535"/>
            </file>
          </resource></contentMetadata>'
        sdb = sdb_for_content_md(m)
        expect(sdb.file_ids).to match_array ["jy496kh1727_sl.mp3", "jy496kh1727_img_1.jp2"]
      end
      it "should be nil if there are no <resource> elements in the contentMetadata" do
        m = '<contentMetadata objectId="jy496kh1727" type="file"></contentMetadata>'
        sdb = sdb_for_content_md(m)
        expect(sdb.file_ids).to be_nil
      end
      it "should be nil if there are no <file> elements in the contentMetadata" do
        m = '<contentMetadata objectId="jy496kh1727" type="file">
          <resource sequence="1" id="jy496kh1727_1" type="file">
            <label>Tape 1, Pass 1</label>
          </resource>
          <resource sequence="2" id="jy496kh1727_2" type="image">
            <label>Image of media (1 of 3)</label>
          </resource></contentMetadata>'
        sdb = sdb_for_content_md(m)
        expect(sdb.file_ids).to be_nil
      end
      it "should be nil if there are no id elements on file elements" do
        m = "#{@content_md_start}<resource type='image'><file/></resource>#{@content_md_end}"
        sdb = sdb_for_content_md(m)
        expect(sdb.file_ids).to be_nil
      end

      # TODO:  multiple file elements in a single resource element

    end # file_ids
    
  end # contentMetadata fields and methods
end