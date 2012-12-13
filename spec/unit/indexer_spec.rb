require 'spec_helper'
require 'stanford-mods'
require 'nokogiri'
require 'rsolr'

describe Indexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @fi = Indexer.new(config_yml_path)
    @hclient = @fi.send(:harvestdor_client)
    require 'yaml'
    @yaml = YAML.load_file(config_yml_path)
  end
  
  describe "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @fi.logger.info("walters_integration_spec logging test message")
      File.exists?(File.join(@yaml['log_dir'], @yaml['log_name'])).should == true
    end
  end

  it "should initialize the harvestdor_client from the config" do
    @hclient.should be_an_instance_of(Harvestdor::Client)
    @hclient.config.default_set.should == @yaml['default_set']
  end
  
  it "druids method should call druids_via_oai method on harvestdor_client" do
    @hclient.should_receive(:druids_via_oai)
    @fi.druids
  end
  
  context "mods method" do
    it "should raise exception if there is no mods for the druid" do
      expect { @fi.mods('oo000oo0000') }.to raise_error(Harvestdor::Errors::MissingMods)
    end
    it "should raise exception if mods for the druid is empty" do
      @hclient.should_receive(:mods).with('oo000oo0000').and_return(Nokogiri::XML('<mods/>'))
      expect { @fi.mods('oo000oo0000') }.to raise_error(RuntimeError, /Empty MODS metadata for oo000oo0000: </)
    end
    it "should return Stanford::Mods::Record" do
      m = '<mods><note>hi</note></mods>'
      @fi.send(:harvestdor_client).stub(:mods).with('oo000oo0000').and_return(Nokogiri::XML(m))
      @fi.mods('oo000oo0000').should be_an_instance_of(Stanford::Mods::Record)
    end
  end
  
  context "content_metadata method" do
    it "should call content_metadata method on harvestdor_client" do
      @hclient.should_receive(:content_metadata).with('oo000oo0000')
      @fi.content_metadata('oo000oo0000')
    end
    it "should raise exception if there is no contentMetadata for the druid" do
      expect { @fi.content_metadata('oo000oo0000') }.to raise_error(Harvestdor::Errors::MissingPurlPage)
    end
  end
  
  context "solr_client" do
    it "should initialize the rsolr client using the options from the config" do
      @fi.stub(:config).and_return { Confstruct::Configuration.new :solr => { :url => 'http://localhost:2345', :a => 1 } }
      RSolr.should_receive(:connect).with(hash_including(:a => 1, :url => 'http://localhost:2345'))
      @fi.solr_client
    end
  end
  
  context "sw_solr_doc" do
    it "should have id value of druid" do
      pending "to be implemented"
      @fi.sw_solr_doc('oo000oo0000')['id'].should == 'oo000oo0000'
    end
    it "should have an access_facet value of 'Online'" do
      pending "to be implemented"
    end
    it "should have a url_fulltext field" do
      pending "to be implemented"
    end
  end
  
  it "should write a Solr doc to the solr index" do
    pending "to be implemented"
    # doc with:  druid, access_facet, url_fulltext
  end

end