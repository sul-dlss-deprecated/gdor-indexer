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

  # coll_hash is in the indexer so each item doesn't need to look up the collection title -- we only look it up once per harvest.
  # @return [Hash<String, String>] collection druids as keys, and the objectLabel from the collection's identityMetadata as the value
  def coll_hash
    @coll_hash ||= {}
  end
  
  # Create a Solr doc, as a Hash, to be added to the SearchWorks Solr index.  
  # Solr doc contents are based on the mods, contentMetadata, etc. for the druid
  # @param [String] druid, e.g. ab123cd4567
  # @param [Stanford::Mods::Record] MODS metadata as a Stanford::Mods::Record object
  # @param [Hash] Hash representing the Solr document
  def sw_solr_doc druid
# FIXME: this needs work   
    sdb = SolrDocBuilder.new(druid, harvestdor_client, logger)
    doc_hash = sdb.doc_hash

    # add things from Indexer level class (info kept here for caching purposes)

    # determine collection druids and their titles and add to solr doc
    coll_druids = sdb.collection_druids
    if coll_druids
      doc_hash[:collection] = []
      doc_hash[:collection_with_title] = []
      sdb.collection_druids.each { |coll_druid|  
        if !coll_hash.keys.include? coll_druid
          @coll_hash[coll_druid] = identity_md_obj_label(coll_druid)
        end
        doc_hash[:collection] << coll_druid
        doc_hash[:collection_with_title] << "#{coll_druid}-|-#{coll_hash[coll_druid]}"
      }
    end

    doc_hash[:url_fulltext] = "#{config.purl}/#{druid}"
    doc_hash
  end
    
  def solr_client
    @solr_client ||= RSolr.connect(config.solr.to_hash)
  end
  
  # given a druid, get its objectLabel from its purl page identityMetadata
  # @param [String] druid, e.g. ab123cd4567
  # @return [String] the value of the <objectLabel> element in the identityMetadata for the object
  def identity_md_obj_label druid
    ng_imd = harvestdor_client.identity_metadata druid
    # TODO: create nom-xml terminology for identityMetadata in harvestdor?
    ng_imd.xpath('identityMetadata/objectLabel').text
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