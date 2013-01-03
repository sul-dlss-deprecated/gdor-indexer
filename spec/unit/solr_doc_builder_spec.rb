require 'spec_helper'

describe SolrDocBuilder do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
    @ng_mods_xml = Nokogiri::XML(@mods_xml)
  end
  
  # NOTE:  
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope
  
  context "mods_to_doc_hash" do
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
    end
    
    context "basic fields" do
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        @basic_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, nil).mods_to_doc_hash
      end
      it "id field should be set to druid" do
        @basic_doc_hash[:id].should == @fake_druid
      end
      it "should have a druid field" do
        @basic_doc_hash[:druid].should == @fake_druid
      end
      it "should have the full MODS in the modsxml field" do
        @basic_doc_hash[:modsxml].should be_equivalent_to @mods_xml
      end 
    end
    
    context "collection_type" do
      it "should be 'Digital Collection' if MODS has <typeOfResource collection='yes'/>" do
        coll_mods_xml = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>hi</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(coll_mods_xml))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.mods_to_doc_hash[:collection_type].should == 'Digital Collection'
      end
      it "should not be present if if MODS doesn't have <typeOfResource collection='yes'/>" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.mods_to_doc_hash[:collection_type].should == nil
      end
    end
    
    context "access_condition_display" do
      it "should be populated when the mods has a top level <accessCondition> element" do
        m = "<mods #{@ns_decl}>
              <accessCondition type='useAndReproduction'>All rights reserved.</accessCondition>
            </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
        sdb.mods_to_doc_hash[:access_condition_display].should == ['All rights reserved.']
      end
      it "should have a value for each accessCondition element" do
        m = "<mods #{@ns_decl}>
              <accessCondition>one</accessCondition>
              <accessCondition></accessCondition>
              <accessCondition>two</accessCondition>
            </mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
        sdb.mods_to_doc_hash[:access_condition_display].should == ['one', 'two']
      end
      it "should not be present when there is no top level <accessCondition> element" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.mods_to_doc_hash[:access_condition_display].should == nil
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
        @title_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, nil).mods_to_doc_hash
      end
      it "should call the appropriate methods in the stanford-mods gem to populate the fields" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        smr = sdb.smods_rec
        smr.should_receive(:sw_short_title).twice
        smr.should_receive(:sw_full_title).exactly(3).times
        smr.should_receive(:sw_addl_titles)
        smr.should_receive(:sw_sort_title)
        sdb.mods_to_doc_hash
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
        @author_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, nil).mods_to_doc_hash
      end
      it "should call the appropriate methods in the stanford-mods gem to populate the fields" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        smr = sdb.smods_rec
        smr.should_receive(:sw_main_author)
        smr.should_receive(:sw_addl_authors)
        smr.should_receive(:sw_person_authors).exactly(3).times
        smr.should_receive(:sw_impersonal_authors)
        smr.should_receive(:sw_corporate_authors)
        smr.should_receive(:sw_meeting_authors)
        smr.should_receive(:sw_sort_author)
        sdb.mods_to_doc_hash
      end
      context "search fields" do
        it "author_1xx_search" do
          @author_doc_hash[:author_1xx_search].should == "Crusty The Clown"
        end
        it "author_7xx_search" do
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
        @subject_doc_hash = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT)).mods_to_doc_hash
      end
      it "should call the appropriate methods in mods_fields to populate the fields" do
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.should_receive(:topic_search)
        sdb.should_receive(:subject_other_subvy_search)
        sdb.mods_to_doc_hash
      end
      it "topic_search" do
        @subject_doc_hash[:topic_search].should == [@genre, @topic]
      end
      it "subject_other_subvy_search" do
        @subject_doc_hash[:subject_other_subvy_search].should == [@temporal, @s_genre]
      end
    end # subject fields
    
  end # mods_to_doc_hash
  
  context "addl_hash_fields" do
    before(:all) do
      @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>")
      cmd_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'></contentMetadata>"
      @ng_pub_xml = Nokogiri::XML("<publicObject id='druid#{@fake_druid}'>#{cmd_xml}</publicObject>")
    end
    before(:each) do
      @hc = double
      @hc.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hc.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @doc_hash = SolrDocBuilder.new(@fake_druid, @hc, nil).addl_hash_fields
    end
    it "should have an access_facet value of 'Online'" do
      @doc_hash[:access_facet].should == 'Online'
    end
    it "should call the appropriate methods in public_xml_fields" do
      sdb = SolrDocBuilder.new(@fake_druid, @hc, nil) 
      sdb.should_receive(:display_type)
      sdb.should_receive(:image_ids)
      sdb.addl_hash_fields
    end
    context "img_info" do
      it "should have img_info as an Array of file ids from content metadata" do
        ng_xml = Nokogiri::XML("<contentMetadata>
              <resource type='image'><file id='foo'/></resource>
              <resource type='image'><file id='bar'/></resource></contentMetadata>")
        sdb = SolrDocBuilder.new(@fake_druid, @hc, nil) 
        sdb.stub(:content_md).and_return(ng_xml.root)
        sdb.addl_hash_fields[:img_info].should == ['foo', 'bar']
      end
    end
  end  # addl_hash_fields

  context "collection?" do
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
    end
    it "should return true if MODS has top level <typeOfResource collection='yes'>" do
      m = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>boo</note></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should be_a_collection
    end
    it "should return false if MODS has no top level <typeOfResource> elements" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should_not be_a_collection
    end
    it "should return false if MODS has top level <typeOfResource> elements without collection attribute" do
      m = "<mods #{@ns_decl}><typeOfResource manuscript='yes'/><note>boo</note></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should_not be_a_collection
    end
    it "should return false if MODS has top level <typeOfResource> element with collection not set to 'yes" do
      m = "<mods #{@ns_decl}><typeOfResource collection='no'/><note>boo</note></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should_not be_a_collection
    end
    it "should return true if MODS has multiple top level <typeOfResource> elements and at least one is a collection" do
      m = "<mods #{@ns_decl}>
            <typeOfResource>cartographic</typeOfResource>
            <typeOfResource collection='yes'/>
            <typeOfResource>still image</typeOfResource>
          </mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
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
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should be_an_image
    end
    it "should return false if MODS has no top level <typeOfResource> elements" do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should_not be_an_image
    end
    it "should return false if MODS has top level <typeOfResource> elements with other values" do
      m = "<mods #{@ns_decl}><typeOfResource>moving image</typeOfResource></mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should_not be_an_image
    end
    it "should return true if MODS has multiple top level <typeOfResource> elements and at least one is still image" do
      m = "<mods #{@ns_decl}>
            <typeOfResource>cartographic</typeOfResource>
            <typeOfResource collection='yes'/>
            <typeOfResource>still image</typeOfResource>
          </mods>"
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
      sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil) 
      sdb.should be_an_image
    end
  end

  context "using Harvestdor::Client" do
    before(:all) do
      config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
      @indexer = Indexer.new(config_yml_path)
    end
    before(:each) do
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

  #------------------------------------------------------------------------------------------------

  context "sw_solr_doc fields" do
    before(:all) do
#      @doc_hash = @fi.sw_solr_doc(@fake_druid)
    end

    # see https://consul.stanford.edu/display/NGDE/Required+and+Recommended+Solr+Fields+for+SearchWorks+documents
    context "DOR specific" do

      context "collection fields for item objects" do
        # FIXME:  update per gryphDOR code / searcworks code / new schema
        it "should populate collection with the id of the parent coll" do
          pending "to be implemented, using controlled vocab, in harvestdor"
        end
        it "should not have a collection_search field, as it is a copy field for collection" do
          pending "to be implemented"
          @doc_hash[:collection_search].should == nil
        end
        # <!--  easy way to indicate collection's parent in UI (may be deprecated in future) -->
        # <field name="collection_with_title" type="string" indexed="false" stored="true" multiValued="true"/>
        it "should have parent_coll_ckey if it is a item object?" do
          pending "to be implemented"
        end
        it "should have collection_type" do
          pending "to be implemented"
          # <!--  used to determine when something is a digital collection -->
          # <field name="collection_type" type="string" indexed="true" stored="true" multiValued="true"/>
        end
      end
      it "should have img_info if there are images associated with the object" do
        pending "to be implemented"
        # <field name="img_info" type="string" indexed="false" stored="true" multiValued="true"/>
      end
    end
    
    context "SearchWorks required fields" do
      it "should have display_type field" do
        # <!-- display_type is a hidden facet for "views" e.g. Images, Maps ...  (might be obsolete) -->
        # <field name="display_type" type="string" indexed="true" stored="false" multiValued="true" omitNorms="true"/>
        pending "to be implemented"
      end
      it "all_search - not a copy field?" do
        pending "to be implemented"
      end

      it "should have a format" do
        pending "to be implemented, using SearchWorks controlled vocab"
      end
    end


    context "SearchWorks recommended fields" do
      it "should have publication date fields" do
        pending "to be implemented"
#        pub_date
#        pub_date_sort
#        pub_date_group_facet
#            we may need a gem or service to compute this - the code from pub_date to pub_date_group is in solrmarc-sw
      end
      it "language" do
        pending "to be implemented"
#        language of the work
#        controlled vocab (though a large one): http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=language&rows=0&facet.limit=1000
      end
    end
    context "MODS/GryphonDOR specific fields" do
      # <field name="access_condition_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="era_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="geographic_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="issue_date_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="physical_location_display" type="string" indexed="false" stored="true" multiValued="true"/>

    end
  end
  

  
  context "pub date fields" do
    it "pub_date" do
      pending "to be implemented"
    end
    it "pub_date_search should not be populated - it is a copy field" do
      pending "to be implemented"
    end
  end
  
  context "subject fields" do
    context "topic fields" do
      it "topic_search" do
        pending "to be implemented"
      end
      it "topic_display should not be populated - it is a copy field" do
        pending "to be implemented"
      end

    end

    context "era fields" do

    end
    context "geographic fields" do
      it "geographic_search" do
        pending "to be implemented"
      end
      it "geographic_facet??" do
        pending "to be implemented"
      end
    end
    
    it "subject_other_search" do
      pending "to be implemented"
    end
    it "subject_other_display should not be populated - it is a copy field" do
      pending "to be implemented"
    end
  end

  context "other publication fields" do
    it "pub_search" do
      pending "to be implemented"
    end
    it "pub_display should not be populated - it is a copy field" do
      pending "to be implemented"
    end
    it "pub_country" do
      pending "to be implemented"
    end
  end

  it "access_condition_display" do
    pending "to be implemented"
  end
  
  it "physical_location_display" do
    pending "to be implemented"
  end
  
  context "abstract and summary fields" do
    it "summary_search" do
      pending "to be implemented"
    end
    it "summary_display should not be populated - it is a copy field" do
      pending "to be implemented"
    end
    
  end
end