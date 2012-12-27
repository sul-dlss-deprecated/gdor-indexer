require 'spec_helper'
require 'stanford-mods'
require 'nokogiri'
require 'rsolr'
require 'equivalent-xml'

describe Indexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @indexer = Indexer.new(config_yml_path)
    require 'yaml'
    @yaml = YAML.load_file(config_yml_path)
    @hclient = @indexer.send(:harvestdor_client)
    @fake_druid = 'oo000oo0000'
  end
  
  describe "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @indexer.logger.info("walters_integration_spec logging test message")
      File.exists?(File.join(@yaml['log_dir'], @yaml['log_name'])).should == true
    end
  end

  it "should initialize the harvestdor_client from the config" do
    @hclient.should be_an_instance_of(Harvestdor::Client)
    @hclient.config.default_set.should == @yaml['default_set']
  end
  
  it "druids method should call druids_via_oai method on harvestdor_client" do
    @hclient.should_receive(:druids_via_oai)
    @indexer.druids
  end
  
  context "solr_client" do
    it "should initialize the rsolr client using the options from the config" do
      @indexer.stub(:config).and_return { Confstruct::Configuration.new :solr => { :url => 'http://localhost:2345', :a => 1 } }
      RSolr.should_receive(:connect).with(hash_including(:a => 1, :url => 'http://localhost:2345'))
      @indexer.solr_client
    end
  end
  
  context "sw_solr_doc fields" do
# FIXME: these should all be tests that solrdocbuilder methods are called
    before(:all) do
      smr = Stanford::Mods::Record.new
      smr.from_str '<mods><note>hi</note></mods>'
#      @doc_hash = @indexer.sw_solr_doc(@fake_druid)
    end
    
    # see https://consul.stanford.edu/display/NGDE/Required+and+Recommended+Solr+Fields+for+SearchWorks+documents
    context "DOR specific" do
      it "should have a druid field" do
        pending
        @doc_hash[:druid].should == @fake_druid
      end
      it "should have a url_fulltext field to the purl landing page" do
        pending
        @doc_hash[:url_fulltext].should == "#{@yaml['purl']}/#{@fake_druid}"
      end
      it "should have the full MODS in the modsxml field" do
        pending "now elsewhere?"
        @indexer.send(:harvestdor_client).stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        doc_hash = @indexer.sw_solr_doc(@fake_druid)
        doc_hash[:modsxml].should be_equivalent_to m
      end
      context "collection fields for item objects" do
        # FIXME:  update per gryphDOR code / searcworks code / new schema
        it "should populate collection with the id of the parent coll" do
          pending "to be implemented, using controlled vocab, in harvestdor"
        end
        it "should not have a collection_search field, as it is a copy field for collection" do
          pending
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
      it "should have a single id value of druid" do
        pending
        @doc_hash[:id].should == @fake_druid
      end
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
    context "SearchWorks strongly recommended fields" do
      it "should have an access_facet value of 'Online'" do
        pending
        @doc_hash[:access_facet].should == 'Online'
      end
      it "should have title fields" do
        pending "to be implemented"
        # short title, full title, alternate title, sorting title ...

#        display (will revert to id if no display title is available)
#            title_display  
#            title_245a_display
#            title_full_display
#        searching (huge impact on generic search results)
#            title_245a_search
#            title_245_search
#        title_sort (if missing, the document will sort last)
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
  
  it "should write a Solr doc to the solr index" do
    pending "to be implemented"
    # doc with:  druid, access_facet, url_fulltext
  end

end