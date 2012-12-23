require 'spec_helper'

describe SolrDocBuilder do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @smr = Stanford::Mods::Record.new
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    coll_mods_xml = "<mods #{@ns_decl}><typeOfResource collection='yes'/></mods>"
    @smr.from_str(coll_mods_xml)
    sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
    @coll_doc_hash = sdb.mods_to_doc_hash
  end

  context "mods_to_doc_hash" do
    before(:all) do
      @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
      @smr.from_str @mods_xml
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil) 
      @basic_doc_hash = sdb.mods_to_doc_hash
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
    
    context "collection_type" do
      it "should be 'Digital Collection' if the object is a collection" do
        @coll_doc_hash[:collection_type].should == 'Digital Collection'
      end
      it "should not be present if the object is not a collection" do
        @basic_doc_hash[:collection_type].should == nil
      end
    end
        
    context "title fields" do
      before(:all) do
        m = "<mods #{@ns_decl}>
          <titleInfo><title>Jerk</title><nonSort>The</nonSort><subTitle>is whom?</subTitle></titleInfo>
          <titleInfo><title>Joke</title></titleInfo>
          <titleInfo type='alternative'><title>Alternative</title></titleInfo>
          </mods>"
        @smr.from_str m
        sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil) 
        @title_doc_hash = sdb.mods_to_doc_hash
      end
      it "should call the appropriate methods in the stanford-mods gem to populate the fields" do
        @smr.should_receive(:sw_short_title).twice
        @smr.should_receive(:sw_full_title).exactly(3).times
        @smr.should_receive(:sw_addl_titles)
        @smr.should_receive(:sw_sort_title)
        @smr.from_str "<mods #{@ns_decl}><note>hi</note></mods>"
        sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
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
        name_mods = "<mods xmlns='#{Mods::MODS_NS}'>
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
        @smr.from_str(name_mods)
        sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil) 
        @author_doc_hash = sdb.mods_to_doc_hash
      end
      it "should call the appropriate methods in the stanford-mods gem to populate the fields" do
        @smr.should_receive(:sw_main_author)
        @smr.should_receive(:sw_addl_authors)
        @smr.should_receive(:sw_person_authors).exactly(3).times
        @smr.should_receive(:sw_impersonal_authors)
        @smr.should_receive(:sw_corporate_authors)
        @smr.should_receive(:sw_meeting_authors)
        @smr.should_receive(:sw_sort_author)
        @smr.from_str "<mods #{@ns_decl}><note>hi</note></mods>"
        sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil) 
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
  end # mods_to_doc_hash
  
  context "addl_hash_fields" do
    before(:all) do
      @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
      @smr.from_str @mods_xml
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil) 
      @doc_hash = sdb.addl_hash_fields
    end
    it "should have an access_facet value of 'Online'" do
      @doc_hash[:access_facet].should == 'Online'
    end    
  end
  
  context "content_metadata_to_doc_hash" do
    
  end


  context "collection?" do
    it "should return true if MODS has top level <typeOfResource collection='yes'>" do
      m = "<mods #{@ns_decl}><typeOfResource collection='yes'/></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should be_a_collection
    end
    it "should return false if MODS has no top level <typeOfResource> elements" do
      m = "<mods #{@ns_decl}><note>boo</note></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should_not be_a_collection
    end
    it "should return false if MODS has top level <typeOfResource> elements without collection attribute" do
      m = "<mods #{@ns_decl}><typeOfResource manuscript='yes'/></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should_not be_a_collection
    end
    it "should return false if MODS has top level <typeOfResource> element with collection not set to 'yes" do
      m = "<mods #{@ns_decl}><typeOfResource collection='no'/></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should_not be_a_collection
    end
    it "should return true if MODS has multiple top level <typeOfResource> elements and at least one is a collection" do
      m = "<mods #{@ns_decl}>
            <typeOfResource>cartographic</typeOfResource>
            <typeOfResource collection='yes'/>
            <typeOfResource>still image</typeOfResource>
          </mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should be_a_collection
    end
  end

  context "image?" do
    it "should return true if MODS has top level <typeOfResource>still image</typeOfResource>" do
      m = "<mods #{@ns_decl}><typeOfResource>still image</typeOfResource></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should be_an_image
    end
    it "should return false if MODS has no top level <typeOfResource> elements" do
      m = "<mods #{@ns_decl}><note>boo</note></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should_not be_an_image
    end
    it "should return false if MODS has top level <typeOfResource> elements with other values" do
      m = "<mods #{@ns_decl}><typeOfResource>moving image</typeOfResource></mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should_not be_an_image
    end
    it "should return true if MODS has multiple top level <typeOfResource> elements and at least one is still image" do
      m = "<mods #{@ns_decl}>
            <typeOfResource>cartographic</typeOfResource>
            <typeOfResource collection='yes'/>
            <typeOfResource>still image</typeOfResource>
          </mods>"
      @smr.from_str m
      sdb = SolrDocBuilder.new(@fake_druid, @smr, nil, nil)
      sdb.should be_an_image
    end
  end



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