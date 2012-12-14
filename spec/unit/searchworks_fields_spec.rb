require 'spec_helper'
# FIXME:  should all these be required, chain-wise, in Indexer class?
require 'searchworks_fields'

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
      end
      it "title_245_search" do
        @sdb.title_245_search.should == "The Jerk A Tale of Tourettes"
      end
      it "title_variant_search" do
        @sdb.title_variant_search.should == ["ta da!", 'and again']
      end
      it "title_related_search should not be populated from mods" do
        expect { @sdb.title_related_search }.to raise_error(NoMethodError)
      end
    end
    context "display fields" do
      it "title_display" do
        @sdb.title_display.should == "The Jerk A Tale of Tourettes"
      end
      it "title_245a_display" do
        @sdb.title_245a_display.should == "The Jerk"
      end
      it "title_245c_display should not be populated from mods" do
        expect { @sdb.title_245c_display }.to raise_error(NoMethodError)
      end
      it "title_full_display" do
        @sdb.title_full_display.should == "The Jerk A Tale of Tourettes"
      end
      it "title_variant_display should not be populated - it is a copy field" do
        expect { @sdb.title_variant_display }.to raise_error(NoMethodError)
      end
    end
    it "title_sort" do
      @sdb.title_sort.should == "Jerk A Tale of Tourettes"
    end
  end
  
  context "author fields" do
    
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