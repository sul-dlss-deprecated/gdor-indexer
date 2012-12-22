# external gems
require 'confstruct'
require 'harvestdor'
# stdlib
require 'logger'

# local files
require 'solr_doc_builder'

# Base class to harvest from DOR via harvestdor gem
class Indexer

  def initialize yml_path, options = {}
    @yml_path = yml_path
    config.configure(YAML.load_file(yml_path)) if yml_path    
    config.configure options 
    yield(config) if block_given?
  end
  
  def config
    @config ||= Confstruct::Configuration.new()
  end

  def logger
    @logger ||= load_logger(config.log_dir, config.log_name)
  end
  
  # return Array of druids contained in the OAI harvest indicated by OAI params in yml configuration file
  # @return [Array<String>] or enumeration over it, if block is given.  (strings are druids, e.g. ab123cd1234)
  def druids
    @druids ||= harvestdor_client.druids_via_oai
  end
  
  # Create a Solr doc, as a Hash, to be added to the SearchWorks Solr index.  
  # Solr doc contents are based on the mods, contentMetadata, etc. for the druid
  # @param [String] druid, e.g. ab123cd4567
  # @param [Stanford::Mods::Record] MODS metadata as a Stanford::Mods::Record object
  # @param [Hash] Hash representing the Solr document
  def sw_solr_doc druid, smods_rec
# FIXME: call mods method here???    
    sdb = SolrDocBuilder.new(druid, smods_rec)
    doc_hash = sdb.mods_to_doc_hash
    doc_hash[:access_facet] = 'Online'  
    doc_hash[:url_fulltext] = "#{config.purl}/#{druid}"
    doc_hash
  end
    
  def solr_client
    @solr_client ||= RSolr.connect(config.solr.to_hash)
  end

  # return the mods for the druid as a Stanford::Mods::Record object
  # @param [String] druid, e.g. ab123cd4567
  # @return [Stanford::Mods::Record] created from the MODS xml for the druid
  def mods druid
    if @mods.nil?
      ng_doc = harvestdor_client.mods druid
      raise "Empty MODS metadata for #{druid}: #{ng_doc.to_xml}" if ng_doc.root.xpath('//text()').empty?
      @mods = Stanford::Mods::Record.new
      @mods.from_nk_node(ng_doc.root)
    end
    @mods
  end
  
  # the public_xml for the druid as a Nokogiri::XML::Document object
  # @param [String] druid, e.g. ab123cd4567
  # @return [Nokogiri::XML::Document] containing the public xml for the druid
  def public_xml druid
    @public_xml ||= harvestdor_client.public_xml druid
  end

  protected #---------------------------------------------------------------------

  def harvestdor_client
    @harvestdor_client ||= Harvestdor::Client.new({:config_yml_path => @yml_path})
  end
  
  # Global, memoized, lazy initialized instance of a logger
  # @param String directory for to get log file
  # @param String name of log file
  def load_logger(log_dir, log_name)
    Dir.mkdir(log_dir) unless File.directory?(log_dir) 
    @logger ||= Logger.new(File.join(log_dir, log_name), 'daily')
  end
    
end