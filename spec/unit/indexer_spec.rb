require 'spec_helper'

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
  
  it "mods method should call mods method on harvestdor_client" do
    @hclient.should_receive(:mods).with('oo000oo0000')
    @fi.mods('oo000oo0000')
  end
  
  it "content_metadata method should call content_metadata method on harvestdor_client" do
    @hclient.should_receive(:content_metadata).with('oo000oo0000')
    @fi.content_metadata('oo000oo0000')
  end

end