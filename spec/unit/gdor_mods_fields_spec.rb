require 'spec_helper'
describe GdorModsFields do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @strio = StringIO.new
    @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
  end

  # NOTE:
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope
  before(:each) do
    @hdor_client = double
    @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
  end

  context "doc_hash_from_mods" do

    # see https://consul.stanford.edu/display/NGDE/Required+and+Recommended+Solr+Fields+for+SearchWorks+documents

    context "summary_search solr field from <abstract>" do
      it "should be populated when the MODS has a top level <abstract> element" do
        m = "<mods #{@ns_decl}><abstract>blah blah</abstract></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:summary_search].should == ['blah blah']
      end
      it "should have a value for each abstract element" do
        m = "<mods #{@ns_decl}>
        <abstract>one</abstract>
        <abstract>two</abstract>
        </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:summary_search].should == ['one', 'two']
      end
      it "should not be present when there is no top level <abstract> element" do
        m = "<mods #{@ns_decl}><relatedItem><abstract>blah blah</abstract></relatedItem></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.doc_hash_from_mods[:summary_search].should == nil
      end
      it "should not be present if there are only empty abstract elements in the MODS" do
        m = "<mods #{@ns_decl}><abstract/><note>notit</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:summary_search].should ==  nil
      end
      it "summary_display should not be populated - it is a copy field" do
        m = "<mods #{@ns_decl}><abstract>blah blah</abstract></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:summary_display].should == nil
      end
    end # summary_search / <abstract>

    it "language: should call sw_language_facet in stanford-mods gem to populate language field" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      smr = sdb.smods_rec
      smr.should_receive(:sw_language_facet)
      sdb.doc_hash_from_mods
    end

    context "physical solr field from <physicalDescription><extent>" do
      it "should be populated when the MODS has mods/physicalDescription/extent element" do
        m = "<mods #{@ns_decl}><physicalDescription><extent>blah blah</extent></physicalDescription></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:physical].should == ['blah blah']
      end
      it "should have a value for each extent element" do
        m = "<mods #{@ns_decl}>
        <physicalDescription>
        <extent>one</extent>
        <extent>two</extent>
        </physicalDescription>
        <physicalDescription><extent>three</extent></physicalDescription>
        </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:physical].should == ['one', 'two', 'three']
      end
      it "should not be present when there is no top level <physicalDescription> element" do
        m = "<mods #{@ns_decl}><relatedItem><physicalDescription><extent>foo</extent></physicalDescription></relatedItem></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.doc_hash_from_mods[:physical].should == nil
      end
      it "should not be present if there are only empty physicalDescription or extent elements in the MODS" do
        m = "<mods #{@ns_decl}><physicalDescription/><physicalDescription><extent/></physicalDescription><note>notit</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:physical].should ==  nil
      end      
    end # physical field from physicalDescription/extent

    context "url_suppl solr field from /mods/relatedItem/location/url" do
      it "should be populated when the MODS has mods/relatedItem/location/url " do
        m = "<mods #{@ns_decl}><relatedItem><location><url>url.org</url></location></relatedItem></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:url_suppl].should == ['url.org']
      end
      it "should have a value for each mods/relatedItem/location/url element" do
        m = "<mods #{@ns_decl}>
        <relatedItem>
        <location><url>one</url></location>
        <location>
        <url>two</url>
        <url>three</url>
        </location>
        </relatedItem>
        <relatedItem><location><url>four</url></location></relatedItem>
        </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:url_suppl].should == ['one', 'two', 'three', 'four']
      end
      it "should not be populated from /mods/location/url element" do
        m = "<mods #{@ns_decl}><location><url>hi</url></location></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.doc_hash_from_mods[:url_suppl].should == nil
      end
      it "should not be present if there are only empty relatedItem/location/url elements in the MODS" do
        m = "<mods #{@ns_decl}>
        <relatedItem><location><url/></location></relatedItem>
        <relatedItem><location/></relatedItem>
        <relatedItem/><note>notit</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:url_suppl].should ==  nil
      end      
    end

    context "toc_search solr field from <tableOfContents>" do
      it "should have a value for each tableOfContents element" do
        m = "<mods #{@ns_decl}>
        <tableOfContents>one</tableOfContents>
        <tableOfContents>two</tableOfContents>
        </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:toc_search].should == ['one', 'two']
      end
      it "should not be present when there is no top level <tableOfContents> element" do
        m = "<mods #{@ns_decl}><relatedItem><tableOfContents>foo</tableOfContents></relatedItem></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.doc_hash_from_mods[:toc_search].should == nil
      end
      it "should not be present if there are only empty tableOfContents elements in the MODS" do
        m = "<mods #{@ns_decl}><tableOfContents/><note>notit</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.doc_hash_from_mods[:toc_search].should ==  nil
      end      
    end

    context "title fields" do
      before(:all) do
        title_mods = "<mods #{@ns_decl}>
        <titleInfo><title>Jerk</title><nonSort>The</nonSort><subTitle>is whom?</subTitle></titleInfo>
        <titleInfo><title>Joke</title></titleInfo>
        <titleInfo type='alternative'><title>Alternative</title></titleInfo>
        </mods>"
        @ng_title_mods = Nokogiri::XML(title_mods)
      end
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_title_mods)
        @title_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
      end
      it "should call the appropriate methods in the stanford-mods gem to populate the fields" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        smr = sdb.smods_rec
        smr.should_receive(:sw_short_title).at_least(:once)
        smr.should_receive(:sw_full_title).at_least(:once)
        smr.should_receive(:sw_addl_titles)
        smr.should_receive(:sw_sort_title)
        sdb.doc_hash_from_mods
      end
      context "search fields" do
        it "title_245a_search" do
          @title_doc_hash[:title_245a_search].should == "The Jerk"
        end
        it "title_245_search" do
          @title_doc_hash[:title_245_search].should == "The Jerk is whom?"
        end
        it "title_variant_search" do
          @title_doc_hash[:title_variant_search].should == ["Joke", "Alternative"]
        end
        it "title_related_search should not be populated from MODS" do
          @title_doc_hash[:title_related_search].should == nil
        end
      end
      context "display fields" do
        it "title_display" do
          @title_doc_hash[:title_display].should == "The Jerk is whom?"
        end
        it "title_245a_display" do
          @title_doc_hash[:title_245a_display].should == "The Jerk"
        end
        it "title_245c_display should not be populated from MODS" do
          @title_doc_hash[:title_245c_display].should == nil
        end
        it "title_full_display" do
          @title_doc_hash[:title_full_display].should == "The Jerk is whom?"
        end
        it 'should remove trailing commas in full titles' do
          title_mods = "<mods #{@ns_decl}>
          <titleInfo><title>Jerk</title><nonSort>The</nonSort><subTitle>is whom,</subTitle></titleInfo>
          <titleInfo><title>Joke</title></titleInfo>
          <titleInfo type='alternative'><title>Alternative</title></titleInfo>
          </mods>"
          @ng_title_mods = Nokogiri::XML(title_mods)
          @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_title_mods)
          @title_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          @title_doc_hash
          @title_doc_hash[:title_full_display].should == "The Jerk is whom"
        end
        it "title_variant_display should not be populated - it is a copy field" do
          @title_doc_hash[:title_variant_display].should == nil
        end
      end
      it "title_sort" do
        @title_doc_hash[:title_sort].should == "Jerk is whom"
      end
    end # title fields  

    context "author fields" do
      before(:all) do
        name_mods = "<mods #{@ns_decl}>
          <name type='personal'>
            <namePart type='given'>John</namePart>
            <namePart type='family'>Huston</namePart>
            <role><roleTerm type='code' authority='marcrelator'>drt</roleTerm></role>
            <displayForm>q</displayForm>
          </name>
          <name type='personal'><namePart>Crusty The Clown</namePart></name>
          <name type='corporate'><namePart>Watchful Eye</namePart></name>
          <name type='corporate'>
            <namePart>Exciting Prints</namePart>
            <role><roleTerm type='text'>lithographer</roleTerm></role>
          </name>
          <name type='conference'><namePart>conference</namePart></name>
        </mods>"
        @ng_name_mods = Nokogiri::XML(name_mods)
      end
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_name_mods)
        @author_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
      end
      it "should call the appropriate methods in the stanford-mods gem to populate the fields" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        smr = sdb.smods_rec
        smr.should_receive(:sw_main_author)
        smr.should_receive(:sw_addl_authors)
        smr.should_receive(:sw_person_authors).exactly(3).times
        smr.should_receive(:sw_impersonal_authors)
        smr.should_receive(:sw_corporate_authors)
        smr.should_receive(:sw_meeting_authors)
        smr.should_receive(:sw_sort_author)
        sdb.doc_hash_from_mods
      end
      context "search fields" do
        it "author_1xx_search" do
          @author_doc_hash[:author_1xx_search].should == "Crusty The Clown"
        end
        it "author_7xx_search" do
          pending "Should this return all authors? or only 7xx authors?"
          @author_doc_hash[:author_7xx_search].should == ["q", "Watchful Eye", "Exciting Prints", "conference"]
        end
        it "author_8xx_search should not be populated from MODS" do
          @author_doc_hash[:author_8xx_search].should == nil
        end
      end
      context "facet fields" do
        it "author_person_facet" do
          @author_doc_hash[:author_person_facet].should == ["q", "Crusty The Clown"]
        end
        it "author_other_facet" do
          @author_doc_hash[:author_other_facet].should == ["Watchful Eye", "Exciting Prints", "conference"]
        end
      end
      context "display fields" do
        it "author_person_display" do
          @author_doc_hash[:author_person_display].should == ["q", "Crusty The Clown"]
        end
        it "author_person_full_display" do
          @author_doc_hash[:author_person_full_display].should == ["q", "Crusty The Clown"]
        end
        it "author_corp_display" do
          @author_doc_hash[:author_corp_display].should == ["Watchful Eye", "Exciting Prints"]
        end
        it "author_meeting_display" do
          @author_doc_hash[:author_meeting_display].should == ["conference"]
        end
      end
      it "author_sort" do
        @author_doc_hash[:author_sort].should == "Crusty The Clown"
      end
    end # author fields

    context "subject fields" do
      before(:all) do
        @genre = 'genre top level'
        @cart_coord = '6 00 S, 71 30 E'
        @s_genre = 'genre in subject'
        @geo = 'Somewhere'
        @geo_code = 'us'
        @hier_geo_country = 'France'
        @s_name = 'name in subject'
        @occupation = 'worker bee'
        @temporal = 'temporal'
        @s_title = 'title in subject'
        @topic = 'topic'
        m = "<mods #{@ns_decl}>
        <genre>#{@genre}</genre>
        <subject><cartographics><coordinates>#{@cart_coord}</coordinates></cartographics></subject>
        <subject><genre>#{@s_genre}</genre></subject>
        <subject><geographic>#{@geo}</geographic></subject>
        <subject><geographicCode authority='iso3166'>#{@geo_code}</geographicCode></subject>
        <subject><hierarchicalGeographic><country>#{@hier_geo_country}</country></hierarchicalGeographic></subject>
        <subject><name><namePart>#{@s_name}</namePart></name></subject>
        <subject><occupation>#{@occupation}</occupation></subject>
        <subject><temporal>#{@temporal}</temporal></subject>
        <subject><titleInfo><title>#{@s_title}</title></titleInfo></subject>
        <subject><topic>#{@topic}</topic></subject>      
        </mods>"
        @ng_subject_mods = Nokogiri::XML(m)
        m_no_subject = "<mods #{@ns_decl}><note>notit</note></mods>"
        @ng_mods_no_subject = Nokogiri::XML(m_no_subject)
      end
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_subject_mods)
        @subject_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, nil).doc_hash_from_mods
      end
      it "should call the appropriate methods in stanford-mods to populate the Solr fields" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.smods_rec.should_receive(:topic_search)
        sdb.smods_rec.should_receive(:geographic_search)
        sdb.smods_rec.should_receive(:subject_other_search)
        sdb.smods_rec.should_receive(:subject_other_subvy_search)
        sdb.smods_rec.should_receive(:subject_all_search)
        sdb.smods_rec.should_receive(:topic_facet)
        sdb.smods_rec.should_receive(:geographic_facet)
        sdb.smods_rec.should_receive(:era_facet)
        sdb.doc_hash_from_mods
      end
      context "search fields" do
        context "topic_search" do
          it "should only include genre and topic" do
            @subject_doc_hash[:topic_search].should == [@genre, @topic]
          end
          context "functional tests checking results from stanford-mods methods" do
            it "should be nil if there are no values in the MODS" do
              @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:topic_search].should == nil
            end
            it "should not be nil if there are only subject/topic elements (no <genre>)" do
              m = "<mods #{@ns_decl}><subject><topic>#{@topic}</topic></subject></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:topic_search].should == [@topic]
            end
            it "should not be nil if there are only <genre> elements (no subject/topic elements)" do
              m = "<mods #{@ns_decl}><genre>#{@genre}</genre></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:topic_search].should == [@genre]
            end
            it "should have a separate value for each topic subelement" do
              m = "<mods #{@ns_decl}>
              <subject>
                <topic>first</topic>
                <topic>second</topic>
              </subject>
              <subject><topic>third</topic></subject>
              </mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:topic_search].should == ['first', 'second', 'third']
            end
          end # functional tests checking results from stanford-mods methods
        end # topic_search

        context "geographic_search" do
          it "should include geographic and hierarchicalGeographic" do
            @subject_doc_hash[:geographic_search].should == [@geo, @hier_geo_country]
          end
          it "should call sw_geographic_search (from stanford-mods gem)" do
            m = "<mods #{@ns_decl}><subject><geographic>#{@geo}</geographic></subject></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.should_receive(:sw_geographic_search).at_least(1).times
            sdb.doc_hash_from_mods
          end
          it "should log an info message when it encounters a geographicCode encoding it doesn't translate" do
            m = "<mods #{@ns_decl}><subject><geographicCode authority='iso3166'>ca</geographicCode></subject></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            sdb.smods_rec.sw_logger.should_receive(:info).with(/#{@fake_druid} has subject geographicCode element with untranslated encoding \(iso3166\): <geographicCode authority=.*>ca<\/geographicCode>/).at_least(1).times
            sdb.doc_hash_from_mods
          end
        end # geographic_search

        context "subject_other_search" do
          it "should include occupation, subject names, and subject titles" do
            @subject_doc_hash[:subject_other_search].should == [@occupation, @s_name, @s_title]
          end
          context "functional tests checking results from stanford-mods methods" do
            it "should be nil if there are no values in the MODS" do
              @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_search].should == nil
            end
            it "should not be nil if there are only subject/name elements" do
              m = "<mods #{@ns_decl}><subject><name><namePart>#{@s_name}</namePart></name></subject></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_search].should == [@s_name]
            end
            it "should not be nil if there are only subject/occupation elements" do
              m = "<mods #{@ns_decl}><subject><occupation>#{@occupation}</occupation></subject></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_search].should == [@occupation]
            end
            it "should not be nil if there are only subject/titleInfo elements" do
              m = "<mods #{@ns_decl}><subject><titleInfo><title>#{@s_title}</title></titleInfo></subject></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_search].should == [@s_title]
            end
            it "should have a separate value for each occupation subelement" do
              m = "<mods #{@ns_decl}>
              <subject>
                <occupation>first</occupation>
                <occupation>second</occupation>
              </subject>
              <subject><occupation>third</occupation></subject>
              </mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_search].should == ['first', 'second', 'third']
            end
          end # functional tests checking results from stanford-mods methods
        end # subject_other_search

        context "subject_other_subvy_search" do
          it "should include temporal and genre SUBelement" do
            @subject_doc_hash[:subject_other_subvy_search].should == [@temporal, @s_genre]
          end
          context "functional tests checking results from stanford-mods methods" do
            it "should be nil if there are no values in the MODS" do
              @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_subvy_search].should == nil
            end
            it "should not be nil if there are only subject/temporal elements (no subject/genre)" do
              m = "<mods #{@ns_decl}><subject><temporal>#{@temporal}</temporal></subject></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_subvy_search].should == [@temporal]
            end
            it "should not be nil if there are only subject/genre elements (no subject/temporal)" do
              m = "<mods #{@ns_decl}><subject><genre>#{@s_genre}</genre></subject></mods>"
              @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
              sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
              sdb.doc_hash_from_mods[:subject_other_subvy_search].should == [@s_genre]
            end
            context "genre subelement" do
              it "should have a separate value for each genre element" do
                m = "<mods #{@ns_decl}>
                <subject>
                  <genre>first</genre>
                  <genre>second</genre>
                </subject>
                <subject><genre>third</genre></subject>
                </mods>"
                @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
                sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
                sdb.doc_hash_from_mods[:subject_other_subvy_search].should == ['first', 'second', 'third']
              end
            end # genre subelement
          end # "functional tests checking results from stanford-mods methods"
        end # subject_other_subvy_search

        context "subject_all_search" do
          it "should contain top level <genre> element data" do
            @subject_doc_hash[:subject_all_search].should include(@genre)
          end
          it "should not contain cartographic sub element" do
            @subject_doc_hash[:subject_all_search].should_not include(@cart_coord)
          end
          it "should not include codes from hierarchicalGeographic sub element" do
            @subject_doc_hash[:subject_all_search].should_not include(@geo_code)
          end
          it "should contain all other subject subelement data" do
            @subject_doc_hash[:subject_all_search].should include(@s_genre)
            @subject_doc_hash[:subject_all_search].should include(@geo)
            @subject_doc_hash[:subject_all_search].should include(@hier_geo_country)
            @subject_doc_hash[:subject_all_search].should include(@s_name)
            @subject_doc_hash[:subject_all_search].should include(@occupation)
            @subject_doc_hash[:subject_all_search].should include(@temporal)
            @subject_doc_hash[:subject_all_search].should include(@s_title)
            @subject_doc_hash[:subject_all_search].should include(@topic)
          end
        end # subject_all_search
      end # search fields
      
      context "facet fields" do
        context "topic_facet" do
          it "should include topic subelement" do
            @subject_doc_hash[:topic_facet].should include(@topic)
          end
          it "should include sw_subject_names" do
            @subject_doc_hash[:topic_facet].should include(@s_name)
          end
          it "should include sw_subject_titles" do
            @subject_doc_hash[:topic_facet].should include(@s_title)
          end
          it "should include occupation subelement" do
            @subject_doc_hash[:topic_facet].should include(@occupation)
          end
          it "should have the trailing punctuation removed" do
            m = "<mods #{@ns_decl}><subject>
            <topic>comma,</topic>
            <occupation>semicolon;</occupation>
            <titleInfo><title>backslash \\</title></titleInfo>
            <name><namePart>internal, punct;uation</namePart></name>
            </subject></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            doc_hash = sdb.doc_hash_from_mods
            doc_hash[:topic_facet].should include('comma')
            doc_hash[:topic_facet].should include('semicolon')
            doc_hash[:topic_facet].should include('backslash')
            doc_hash[:topic_facet].should include('internal, punct;uation')
          end
        end # topic_facet
        
        context "geographic_facet" do
          it "should include geographic subelement" do
            @subject_doc_hash[:geographic_facet].should include(@geo)
          end
          it "should be like geographic_search with the trailing punctuation (and preceding spaces) removed" do
            m = "<mods #{@ns_decl}><subject>
            <geographic>comma,</geographic>
            <geographic>semicolon;</geographic>
            <geographic>backslash \\</geographic>
            <geographic>internal, punct;uation</geographic>
            </subject></mods>"
            @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
            sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
            doc_hash = sdb.doc_hash_from_mods
            doc_hash[:geographic_facet].should include('comma')
            doc_hash[:geographic_facet].should include('semicolon')
            doc_hash[:geographic_facet].should include('backslash')
            doc_hash[:geographic_facet].should include('internal, punct;uation')
          end
        end

        it "era_facet should be temporal subelement with the trailing punctuation removed" do
          m = "<mods #{@ns_decl}><subject>
          <temporal>comma,</temporal>
          <temporal>semicolon;</temporal>
          <temporal>backslash \\</temporal>
          <temporal>internal, punct;uation</temporal>
          </subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:era_facet].should include('comma')
          doc_hash[:era_facet].should include('semicolon')
          doc_hash[:era_facet].should include('backslash')
          doc_hash[:era_facet].should include('internal, punct;uation')
        end
      end # facet fields
    end # subject fields

    context 'publication date fields' do
      it 'should populate all date fields' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>13th century AH / 19th CE</dateIssued>
            </originInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
        doc_hash[:pub_date].should == '19th century'
        doc_hash[:pub_date_sort].should == '1800'
        doc_hash[:publication_year_isi].should == '1800'
        doc_hash[:pub_year_tisim].should == '1800' # date slider
        doc_hash[:pub_date_group_facet].should == ["More than 50 years ago"]
        doc_hash[:pub_date_display].should == '13th century AH / 19th CE'
        doc_hash[:imprint_display].should == '13th century AH / 19th CE'
      end
      it 'should not populate the date slider for BC dates' do
        m = "<mods #{@ns_decl}><originInfo><dateIssued>199 B.C.</dateIssued></originInfo></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
        doc_hash.has_key?(:pub_year_tisim).should == false
      end
      
      context 'pub_date_sort integration tests' do
        before :each do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}> </mods>"))
          @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        end
        it 'should work on normal dates' do
          @sdb.smods_rec.stub(:pub_date).and_return('1945')
          @sdb.doc_hash_from_mods[:pub_date_sort].should == '1945'
        end
        it 'should work on 3 digit dates' do
          @sdb.smods_rec.stub(:pub_date).and_return('945')
          @sdb.doc_hash_from_mods[:pub_date_sort].should == '0945'
        end
        it 'should work on century dates' do
          @sdb.smods_rec.stub(:pub_date).and_return('16--')
          @sdb.doc_hash_from_mods[:pub_date_sort].should == '1600'
        end
        it 'should work on 3 digit century dates' do
          @sdb.smods_rec.stub(:pub_date).and_return('9--')
          @sdb.doc_hash_from_mods[:pub_date_sort].should == '0900'
        end
      end # pub_date_sort

      context "pub_date_group_facet integration tests" do
        it 'should generate the groups' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>1904</dateCreated>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_date_group_facet].should == ['More than 50 years ago']
        end
        it 'should work for a modern date too' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>2012</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_date_group_facet].should == ['Last 3 years']
        end
        it 'should be missing for a missing date' do
          m = "<mods #{@ns_decl}><note>hi</note></originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_date_groups_facet].should == nil
        end
      end # context pub date groups

      context "pub_year_tisim for date slider" do
        it "should take single dateCreated" do
          m = "<mods #{@ns_decl}><originInfo>
          <dateCreated>1904</dateCreated>
          </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1904'
        end
        it "should correctly parse a ranged date" do
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>Text dated June 4, 1594; miniatures added by 1596</dateCreated>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1594'
        end
        it "should find year in an expanded English form" do
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>Aug. 3rd, 1886</dateCreated>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1886'
        end
        it "should remove question marks and brackets" do
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>Aug. 3rd, [18]86?</dateCreated>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1886'
        end
        it 'should ignore an s after the decade' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>early 1890s</dateCreated>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1890'
        end
        it 'should choose a date ending with CE if there are multiple dates' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>7192 AM (li-Adam) / 1684 CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1684'
        end
        it 'should take first year from hyphenated range (for now)' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>1282 AH / 1865-6 CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
          doc_hash[:pub_year_tisim].should == '1865'
        end
      end # pub_year_tisim method

      context "difficult pub dates" do
        it "should handle multiple pub dates" do
          pending "to be implemented - esp for date slider"
        end
        it "should choose the latest date???" do
          pending "to be implemented - esp for sorting and date slider"
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>1904</dateCreated>
                <dateCreated>1905</dateCreated>
                <dateIssued>1906</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date_sort].should == '1904'
          doc_hash[:pub_year_tisim].should == '1904'
          doc_hash[:pub_date].should == '1904'
          doc_hash[:pub_year_tisim].should == ['1904','1905','1906']
        end

        it 'should handle nnth century dates' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>13th century AH / 19th CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date].should == '19th century'
          doc_hash[:pub_date_sort].should =='1800'
          doc_hash[:pub_year_tisim].should == '1800'
          doc_hash[:publication_year_isi].should == '1800'
          doc_hash[:imprint_display].should == '13th century AH / 19th CE'
        end
        it 'should handle multiple CE dates' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>6 Dhu al-Hijjah 923 AH / 1517 CE -- 7 Rabi I 924 AH / 1518 CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date_sort].should =='1517'
          doc_hash[:pub_date].should == '1517'
          doc_hash[:pub_year_tisim].should == '1517'
        end
        it 'should handle specific century case from walters' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>Late 14th or early 15th century CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date_sort].should =='1400'
          doc_hash[:pub_year_tisim].should =='1400'
          doc_hash[:publication_year_isi].should == '1400'
          doc_hash[:pub_date].should == '15th century'
          doc_hash[:imprint_display].should == 'Late 14th or early 15th century CE'
        end
        it 'should work on explicit 3 digit dates' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>966 CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date_sort].should =='0966'
          doc_hash[:pub_date].should == '966'
          doc_hash[:pub_year_tisim].should == '0966'
          doc_hash[:publication_year_isi].should == '0966'
          doc_hash[:imprint_display].should == '966 CE'
        end
        it 'should work on 3 digit century dates' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateIssued>3rd century AH / 9th CE</dateIssued>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date_sort].should =='0800'
          doc_hash[:pub_year_tisim].should =='0800'
          doc_hash[:pub_date].should == '9th century'
          doc_hash[:publication_year_isi].should == '0800'
          doc_hash[:imprint_display].should == '3rd century AH / 9th CE'
        end
        it 'should work on 3 digit BC dates' do
          m = "<mods #{@ns_decl}><originInfo>
                <dateCreated>300 B.C.</dateCreated>
              </originInfo></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
          doc_hash = sdb.doc_hash_from_mods
          doc_hash[:pub_date_sort].should =='-700'
          doc_hash[:pub_year_tisim].should == nil
          doc_hash[:pub_date].should == '300 B.C.'
          doc_hash[:imprint_display].should =='300 B.C.'
          # doc_hash[:creation_year_isi].should =='-300'
        end
      end # difficult pub dates

    end # publication date fields
  end # doc_hash_from_mods

  context "format" do
    it "should get format from call to stanford-mods searchworks format method " do
      m = "<mods #{@ns_decl}><typeOfResource>still image</typeOfResouce></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.should_receive(:format).and_call_original
      sdb.smods_rec.format.should == ['Image']
    end
    it "should return nothing if there is no format info" do
      m = "<mods #{@ns_decl}><originInfo>
      <dateCreated>1904</dateCreated>
      </originInfo></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.smods_rec.format.should == []
    end
  end # context format

end