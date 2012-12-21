require 'spec_helper'
# FIXME:  should all these be required, chain-wise, in Indexer class?
require 'searchworks_fields'
require 'stanford-mods/searchworks'

describe 'SearchworksFields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @smr = Stanford::Mods::Record.new
  end

  context "title fields" do
    before(:all) do
      title_mods = "<mods xmlns='#{Mods::MODS_NS}'>
                      <titleInfo>
                        <title>Jerk</title>
                        <subTitle>A Tale of Tourettes</subTitle>
                        <nonSort>The</nonSort>
                      </titleInfo>
                      <titleInfo type='alternative'>
                        <title>ta da!</title>
                      </titleInfo>
                      <titleInfo type='alternative'>
                        <title>and again</title>
                      </titleInfo>
                    </mods>"
      @smr.from_str(title_mods)
      @sdb = SolrDocBuilder.new(@fake_druid, @smr)
    end
    context "search fields" do
      it "title_245a_search" do
        @sdb.title_245a_search.should == "The Jerk"
        @smr.should_receive(:sw_short_title) # from stanford-mods gem
        @sdb.title_245a_search
      end
      it "title_245_search" do
        @sdb.title_245_search.should == "The Jerk A Tale of Tourettes"
        @smr.should_receive(:sw_full_title) # from stanford-mods gem
        @sdb.title_245_search
      end
      it "title_variant_search" do
        @sdb.title_variant_search.should == ["ta da!", 'and again']
        @smr.should_receive(:sw_addl_titles) # from stanford-mods gem
        @sdb.title_variant_search
      end
      it "title_related_search should not be populated from MODS" do
        expect { @sdb.title_related_search }.to raise_error(NoMethodError)
      end
    end
    context "display fields" do
      it "title_display" do
        @sdb.title_display.should == "The Jerk A Tale of Tourettes"
        @smr.should_receive(:sw_full_title) # from stanford-mods gem
        @sdb.title_display
      end
      it "title_245a_display" do
        @sdb.title_245a_display.should == "The Jerk"
        @smr.should_receive(:sw_short_title) # from stanford-mods gem
        @sdb.title_245a_display
      end
      it "title_245c_display should not be populated from MODS" do
        expect { @sdb.title_245c_display }.to raise_error(NoMethodError)
      end
      it "title_full_display" do
        @sdb.title_full_display.should == "The Jerk A Tale of Tourettes"
        @smr.should_receive(:sw_full_title) # from stanford-mods gem
        @sdb.title_full_display
      end
      it "title_variant_display should not be populated - it is a copy field" do
        expect { @sdb.title_variant_display }.to raise_error(NoMethodError)
      end
    end
    it "title_sort" do
      @sdb.title_sort.should == "Jerk A Tale of Tourettes"
      @smr.should_receive(:sw_sort_title) # from stanford-mods gem
      @sdb.title_sort
    end
  end
  
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
      @sdb = SolrDocBuilder.new(@fake_druid, @smr)
    end
    context "search fields" do
      it "author_1xx_search" do
        @sdb.author_1xx_search.should == "Crusty The Clown"
        @smr.should_receive(:sw_main_author) # from stanford-mods gem
        @sdb.author_1xx_search
      end
      it "author_7xx_search" do
        @sdb.author_7xx_search.should == ["q", "Watchful Eye", "Exciting Prints", "conference"]
        @smr.should_receive(:sw_addl_authors) # from stanford-mods gem
        @sdb.author_7xx_search
      end
      it "author_8xx_search should not be populated from MODS" do
        expect { @sdb.author_8xx_search }.to raise_error(NoMethodError)
      end
    end
    context "facet fields" do
      it "author_person_facet" do
        @sdb.author_person_facet.should == ["q", "Crusty The Clown"]
        @smr.should_receive(:sw_person_authors) # from stanford-mods gem
        @sdb.author_person_facet
      end
      it "author_other_facet" do
        @sdb.author_other_facet.should == ["Watchful Eye", "Exciting Prints", "conference"]
        @smr.should_receive(:sw_impersonal_authors) # from stanford-mods gem
        @sdb.author_other_facet
      end
    end
    context "display fields" do
      it "author_person_display" do
        @sdb.author_person_display.should == ["q", "Crusty The Clown"]
      end
      it "author_person_full_display" do
        @sdb.author_person_full_display.should == ["q", "Crusty The Clown"]
      end
      it "author_corp_display" do
        @sdb.author_corp_display.should == ["Watchful Eye", "Exciting Prints"]
        @smr.should_receive(:sw_corporate_authors) # from stanford-mods gem
        @sdb.author_corp_display
      end
      it "author_meeting_display" do
        @sdb.author_meeting_display.should == ["conference"]
        @smr.should_receive(:sw_meeting_authors) # from stanford-mods gem
        @sdb.author_meeting_display
      end
    end
    it "author_sort" do
      @sdb.author_sort.should == "Crusty The Clown"
      @smr.should_receive(:sw_sort_author) # from stanford-mods gem
      @sdb.author_sort
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