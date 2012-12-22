require 'spec_helper'
# FIXME:  should all these be required, chain-wise, in Indexer class?
require 'searchworks_fields'
require 'stanford-mods/searchworks'

describe 'SearchworksFields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @smr = Stanford::Mods::Record.new
  end

  context "pub date fields" do
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