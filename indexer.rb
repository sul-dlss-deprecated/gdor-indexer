# external gems
require 'confstruct'
require 'harvestdor'
require 'rsolr'
# stdlib
require 'logger'
require 'threach'

# local files
require 'solr_doc_builder'

# Base class to harvest from DOR via harvestdor gem
class Indexer


  def initialize yml_path, options = {}
    @yml_path = yml_path
    Indexer.config.configure(YAML.load_file(yml_path)) if yml_path    
    Indexer.config.configure options 
    yield(Indexer.config) if block_given?
  end

  def self.config
    @@config ||= Confstruct::Configuration.new()
  end

  def logger
    @logger ||= load_logger(Indexer.config.log_dir, Indexer.config.log_name)
  end

  # per this Indexer's config options 
  #  harvest the druids via OAI
  #   create a Solr document for each druid suitable for SearchWorks
  #   write the result to the SearchWorks Solr index
  def harvest_and_index
    
    druids.threach(4) do  |id|  
      logger.debug "Indexing #{id}"
      begin
      solr_client.add(sw_solr_doc(id))
      # update DOR object's workflow datastream??   for harvest?  for indexing?
      rescue => e
        logger.error "Failed to index #{id}: #{e.message}"
      end
  end
  end

  # return Array of druids contained in the OAI harvest indicated by OAI params in yml configuration file
  # @return [Array<String>] or enumeration over it, if block is given.  (strings are druids, e.g. ab123cd1234)
  def druids
    @druids ||= harvestdor_client.druids_via_oai
  end
  # @return [boolean] true if the collection has a catkey
  def collection_is_mergable?
    sdb=SolrDocBuilder.new(collection_druid, harvestdor_client, logger)
    if sdb.catkey
      logger.info "Collection #{collection_druid} is being merged with cat key #{sdb.catkey}"
    end
    false
  end
  # @return [String]The collection object catkey or nil if none exists
  def catkey
    sdb=SolrDocBuilder.new(collection_druid, harvestdor_client, logger)
    sdb.catkey
  end
  # Create a solr document for the collection druid suitable for searchworks
  # write the result to the SearchWorks Solr Index
  # @param [String] druid 
  def index_collection_druid
    if collection_is_mergable?
      begin
        logger.debug "Merging collection object #{collection_druid} into #{catkey}"
        RecordMerger.merge(collection_druid,catkey)
      rescue => e
      end
    else
    begin
      logger.debug "Indexing collection object #{collection_druid}"
      solr_client.add(sw_solr_doc(collection_druid)) unless collection_druid.nil?
      # update DOR object's workflow datastream??   for harvest?  for indexing?
    rescue => e
      logger.error "Failed to index collection object #{collection_druid}: #{e.message}"
    end
    end
  end

  # return String indicating the druid of a collection object, or nil if there is no collection druid
  # @return [Array<String>] or enumeration over it, if block is given.  (strings are druids, e.g. ab123cd1234)
  def collection_druid
    # @collection_druid ||= 
    begin
      if Indexer.config[:default_set].include? "is_member_of_collection_"
        return Indexer.config[:default_set].gsub("is_member_of_collection_",'')
      else
        return nil
      end
    end
  end

  # coll_hash is in the indexer so each item doesn't need to look up the collection title -- we only look it up once per harvest.
  # @return [Hash<String, String>] collection druids as keys, and the objectLabel from the collection's identityMetadata as the value
  def coll_hash
    @coll_hash ||= {}
  end

  def self.format_hash
    @@format_hash ||= {}
  end

  # Create a Solr doc, as a Hash, to be added to the SearchWorks Solr index.  
  # Solr doc contents are based on the mods, contentMetadata, etc. for the druid
  # @param [String] druid, e.g. ab123cd4567
  # @param [Stanford::Mods::Record] MODS metadata as a Stanford::Mods::Record object
  # @param [Hash] Hash representing the Solr document
  def sw_solr_doc druid
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
        if !Indexer.format_hash.keys.include? coll_druid
          Indexer.format_hash[coll_druid]={}
        end
        #store the format(s) of this object with each collection, so when the collections are being indexed, they get all of the formats of the members
        if doc_hash[:format]
          if doc_hash[:format].kind_of?(Array)
            doc_hash[:format].each do |format|
              Indexer.format_hash[coll_druid][format]=format
            end
          else
            Indexer.format_hash[coll_druid][doc_hash[:format]]=doc_hash[:format]
          end
          end
          if catkey
            doc_hash[:collection] << catkey
          else
        doc_hash[:collection] << coll_druid
        end
        doc_hash[:collection_with_title] << "#{coll_druid}-|-#{coll_hash[coll_druid]}"
        }
      end

      doc_hash[:url_fulltext] = "#{Indexer.config.purl}/#{druid}"
      doc_hash
    end

    def solr_client
      @solr_client ||= RSolr.connect(Indexer.config.solr.to_hash)
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