# encoding: UTF-8
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
    it "id field should be set to druid" do
      @doc_hash[:id].should == @fake_druid
    end
    it "should have a druid field" do
      @doc_hash[:druid].should == @fake_druid
    end
    it "should have the full MODS in the modsxml field" do
      @doc_hash[:modsxml].should be_equivalent_to @mods_xml
    end 
    it "should call doc_hash_from_mods to populate hash fields from MODS" do
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      sdb.should_receive(:doc_hash_from_mods)
      sdb.doc_hash
    end
    it "should have an access_facet value of 'Online'" do
      @doc_hash[:access_facet].should == 'Online'
    end
    it "should call the appropriate methods in public_xml_fields" do
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_receive(:display_type)
      sdb.should_receive(:image_ids)
      sdb.should_receive(:format)
      sdb.doc_hash
    end
    context "img_info" do
      it "should have img_info as an Array of file ids from content metadata" do
        ng_xml = Nokogiri::XML("<contentMetadata type='image'>
        <resource type='image'><file id='foo'/></resource>
        <resource type='image'><file id='bar'/></resource></contentMetadata>")
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
        sdb.stub(:content_md).and_return(ng_xml.root)
        sdb.doc_hash[:img_info].should == ['foo', 'bar']
      end
    end
  end

  context "doc_hash_from_mods" do
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
    end

    # see https://consul.stanford.edu/display/NGDE/Required+and+Recommended+Solr+Fields+for+SearchWorks+documents

    context "collection_type" do
      it "should be 'Digital Collection' if MODS has <typeOfResource collection='yes'/>" do
        coll_mods_xml = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>hi</note></mods>"
        hc = double
        hc.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(coll_mods_xml))
        hc.stub(:public_xml).with(@fake_druid).and_return(nil)
        sdb = SolrDocBuilder.new(@fake_druid, hc, Logger.new(@strio))
        sdb.doc_hash_from_mods[:collection_type].should == 'Digital Collection'
      end
      it "should not be present if if MODS doesn't have <typeOfResource collection='yes'/>" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.doc_hash_from_mods[:collection_type].should == nil
      end
    end
    
    context "display_type" do
      it "should be hydrus_collection for hydrus collections" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:collection?).and_return(true)
        sdb.add_display_type.should eql("hydrus")
        sdb.display_type.should eql("hydrus_collection")
      end
      it "should be hydrus_object for hydrus objects" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        Indexer.stub(:config).and_return({:add_display_type => 'hydrus'})
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
        sdb.stub(:collection?).and_return(false)
        sdb.add_display_type.should eql("hydrus")
        sdb.display_type.should eql("hydrus_object")      
      end
    end

    context "<abstract> --> summary_search" do
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
    it "collection_language should aggregate item languages" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio))
      smr = sdb.smods_rec
      smr.should_receive(:sw_language_facet)
      Indexer.language_hash[@fake_druid] = ['English']
      sdb.doc_hash_from_mods
      sdb.collection_language.should == ['English']
    end
    

    context "<physicalDescription><extent> --> physical" do
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

    context " /mods/relatedItem/location/url --> url_suppl " do
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

    context "<tableOfContents> --> toc_search" do
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
      end
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_subject_mods)
        @subject_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
      end
      it "should call the appropriate methods in mods_fields mixin to populate the Solr fields" do
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
      it "topic_search" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_subject_mods)
        @subject_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)).doc_hash_from_mods
        @subject_doc_hash[:topic_search].should == [@genre, @topic]
      end
      it "geographic_search" do
        @subject_doc_hash[:geographic_search].should == [@geo, @hier_geo_country]
      end
      it "subject_other_search" do
        @subject_doc_hash[:subject_other_search].should == [@occupation, @s_name, @s_title]
      end
      it "subject_other_subvy_search" do
        @subject_doc_hash[:subject_other_subvy_search].should == [@temporal, @s_genre]
      end
      it "subject_all_search" do
        @subject_doc_hash[:subject_all_search].should include(@genre)
        @subject_doc_hash[:subject_all_search].should include(@topic)
        @subject_doc_hash[:subject_all_search].should include(@geo)
        @subject_doc_hash[:subject_all_search].should include(@hier_geo_country)
        @subject_doc_hash[:subject_all_search].should include(@occupation)
        @subject_doc_hash[:subject_all_search].should include(@s_name)
        @subject_doc_hash[:subject_all_search].should include(@s_title)
        @subject_doc_hash[:subject_all_search].should include(@temporal)
        @subject_doc_hash[:subject_all_search].should include(@s_genre)
      end
      it "topic_facet" do
        @subject_doc_hash[:topic_facet].should include(@topic)
        @subject_doc_hash[:topic_facet].should include(@s_name)
        @subject_doc_hash[:topic_facet].should include(@occupation)
        @subject_doc_hash[:topic_facet].should include(@s_title)
      end
      it "geographic_facet" do
        @subject_doc_hash[:geographic_facet].should include(@geo)
      end
      it "era_facet" do
        @subject_doc_hash[:era_facet].should include(@temporal)
      end
    end # subject fields
    context 'date fields' do
      it 'should populate all date fields' do
        m = "<mods #{@ns_decl}><originInfo><dateIssued>13th century AH / 19th CE</dateIssued><issuance>monographic</issuance></originInfo>"
         @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
         sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT)).doc_hash_from_mods
         sdb[:pub_date].should == '19th century'
         sdb[:pub_date_sort].should == '1800'
         sdb[:pub_date_group_facet].should == ["More than 50 years ago"]
         sdb[:pub_date_display].should == '13th century AH / 19th CE'
         sdb[:publication_year_isi].should == '1800'
         sdb[:imprint_display].should == '13th century AH / 19th CE'
      end
    end
  end # doc_hash_from_mods

  context "collection?" do
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
    end
    it "should return true if MODS has top level <typeOfResource collection='yes'>" do
      m = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>boo</note></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should be_a_collection
    end
    it "should return false if MODS has no top level <typeOfResource> elements" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_not be_a_collection
    end
    it "should return false if MODS has top level <typeOfResource> elements without collection attribute" do
      m = "<mods #{@ns_decl}><typeOfResource manuscript='yes'/><note>boo</note></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_not be_a_collection
    end
    it "should return false if MODS has top level <typeOfResource> element with collection not set to 'yes" do
      m = "<mods #{@ns_decl}><typeOfResource collection='no'/><note>boo</note></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_not be_a_collection
    end
    it "should return true if MODS has multiple top level <typeOfResource> elements and at least one is a collection" do
      m = "<mods #{@ns_decl}>
      <typeOfResource>cartographic</typeOfResource>
      <typeOfResource collection='yes'/>
      <typeOfResource>still image</typeOfResource>
      </mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should be_a_collection
    end
  end

  context "image?" do
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
    end
    it "should return true if MODS has top level <typeOfResource>still image</typeOfResource>" do
      m = "<mods #{@ns_decl}><typeOfResource>still image</typeOfResource></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should be_an_image
    end
    it "should return false if MODS has no top level <typeOfResource> elements" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_not be_an_image
    end
    it "should return false if MODS has top level <typeOfResource> elements with other values" do
      m = "<mods #{@ns_decl}><typeOfResource>moving image</typeOfResource></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should_not be_an_image
    end
    it "should return true if MODS has multiple top level <typeOfResource> elements and at least one is still image" do
      m = "<mods #{@ns_decl}>
      <typeOfResource>cartographic</typeOfResource>
      <typeOfResource collection='yes'/>
      <typeOfResource>still image</typeOfResource>
      </mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(@strio)) 
      sdb.should be_an_image
    end
  end

  context "using Harvestdor::Client" do
    before(:all) do
      config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
      solr_yml_path = File.join(File.dirname(__FILE__), "..", "..", "config", "solr.yml")
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

    context "getting a collection's goodies" do
      it "does something" do
        pending "to be implemented"
      end
    end
  end # context using Harvestdor::Client

end