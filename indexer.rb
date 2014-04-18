# external gems
require 'confstruct'
require 'harvestdor-indexer'
require 'rsolr'
require 'mail'
require 'threach'
# stdlib
require 'logger'
require 'net/smtp'
# local files
require 'solr_doc_builder'
require 'hash_mixin'
require 'nokogiri_xml_node_mixin'
require 'oai_client_mixin'
# Base class to harvest from DOR via harvestdor gem
class Indexer < Harvestdor::Indexer

  def initialize yml_path, solr_config_path, options = {}
    @oai_harvest_count = 0
    @whitelist_count = 0
    @success_count = 0
    @error_count = 0
    @total_time_to_solr = 0
    @total_time_to_parse = 0
    @retries = 0
    @yml_path = yml_path
    @validation_messages = []
    solr_config = YAML.load_file(solr_config_path) if solr_config_path && File.exists?(solr_config_path)
    Indexer.config.configure(YAML.load_file(yml_path)) if yml_path && File.exists?(yml_path)
    Indexer.config.configure options 
    Indexer.config[:solr] = {:url => solr_config["solr"]["url"], :read_timeout => 3600, :open_timeout => 3600}
    yield(Indexer.config) if block_given?
  end

  # to allow class level access to config variables for record_merger and solr_doc_builder
  #  (rather than passing a lot of params to constructor)
  def self.config
    @@config ||= Confstruct::Configuration.new()
  end
  def config
    Indexer.config
  end
  def logger
    @logger ||= load_logger(config.log_dir ||= 'logs', config.log_name)
  end
  
  # per this Indexer's config options 
  #  harvest the druids via OAI
  #   create a Solr document for each druid suitable for SearchWorks and
  #   write the result to the SearchWorks Solr index
  #  (all members of the collection + coll rec itself)
  def harvest_and_index(nocommit = false)
    start_time=Time.now 
    logger.info("Started harvest_and_index at #{start_time}")

    if !coll_sdb.coll_object?
      logger.fatal("#{coll_druid_from_config} is not a collection object!! (per identityMetaadata)  Ending indexing.")
    else
      if whitelist.empty?
        @oai_harvest_count = druids.size
        druids.threach(3) { |druid| index_item druid }
      else
        logger.info("Using whitelist from #{config.whitelist}")
        @whitelist_count = whitelist.size
        whitelist.threach(3) { |druid| index_item druid }
      end
      index_coll_obj_per_config
    end
    
    if !nocommit && coll_sdb.coll_object?
      logger.info("Beginning Commit.")
      solr_client.commit
      logger.info("Finished Commit.")
    elsif nocommit
      logger.info("Skipping commit per nocommit flag")
    end

    @total_time = elapsed_time(start_time)
    logger.info("Finished harvest_and_index at #{Time.now}")
    logger.info("Total elapsed time for harvest and index: #{(@total_time/60).round(2)} minutes")

    log_results
    email_results
  end
  
  # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.  
  #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
  def index_item druid
    if blacklist.include?(druid)
      logger.info("#{druid} is on the blacklist and will have no Solr doc created")
    else
      begin
        sdb = SolrDocBuilder.new(druid, harvestdor_client, logger)

        fields_to_add = {
          :druid => druid,
          :url_fulltext => "http://purl.stanford.edu/#{druid}",
          :access_facet => 'Online',
          :display_type => sdb.display_type,  # defined in public_xml_fields
        }
        fields_to_add[:file_id] = sdb.file_ids unless !sdb.file_ids  # defined in public_xml_fields

        ckey = sdb.catkey
        if ckey
          require 'record_merger'
          logger.debug "item #{druid} merged into #{ckey}"
          add_coll_info fields_to_add, sdb.coll_druids_from_rels_ext # defined in public_xml_fields
          @validation_messages = validate_item(druid, fields_to_add)
          RecordMerger.merge_and_index(ckey, fields_to_add)
        else
          logger.info "indexing item #{druid}"
          doc_hash = sdb.doc_hash
          doc_hash.combine fields_to_add
          add_coll_info doc_hash, sdb.coll_druids_from_rels_ext # defined in public_xml_fields
          @validation_messages = validate_item(druid, doc_hash)
          @validation_messages.concat sdb.validate_mods(druid, doc_hash)
          solr_add(doc_hash, druid)
        end
        @success_count += 1
      rescue => e
        @error_count += 1
        logger.error "Failed to index item #{druid}: #{e.message} #{e.backtrace}"
      end
    end
  end

  # Create Solr document for the collection druid suitable for SearchWorks
  #  and write the result to the SearchWorks Solr Index
  # @param [String] druid 
  def index_coll_obj_per_config
    # we have already affirmed that coll_druid_from_config is a collection record in harvest_and_index method
    begin
      coll_druid = coll_druid_from_config
      fields_to_add = {
        :druid => coll_druid,
        :url_fulltext => "http://purl.stanford.edu/#{coll_druid}",
        :access_facet => 'Online',
        :collection_type => 'Digital Collection',
        :display_type => coll_display_types_from_items[coll_druid]
      }
      if coll_catkey
        require 'record_merger'
        logger.debug "Merging collection object #{coll_druid} into #{coll_catkey}"
        @validation_messages = validate_collection(coll_druid, fields_to_add)
        RecordMerger.merge_and_index(coll_catkey, fields_to_add)
      else
        logger.info "Indexing collection object #{coll_druid}"
        doc_hash = coll_sdb.doc_hash
        doc_hash.combine fields_to_add
        # add item formats
        addl_formats = coll_formats_from_items[coll_druid] # guaranteed to be Array or nil
        if addl_formats && !addl_formats.empty?
          addl_formats.concat(doc_hash[:format]) if doc_hash[:format] # doc_hash[:format] guaranteed to be Array
          doc_hash[:format] = addl_formats.uniq
        end
        @validation_messages = validate_collection(coll_druid, doc_hash)
        @validation_messages.concat coll_sdb.validate_mods(coll_druid, doc_hash)
        solr_add(doc_hash, coll_druid) unless coll_druid.nil?
      end
      @success_count += 1
    rescue => e
      logger.error "Failed to merge collection object #{coll_druid_from_config}: #{e.message}"
      @error_count += 1
    end
  end

  # add coll level data to this solr doc and/or cache collection level information
  # @param [Hash] Hash representing the Solr document (for an item)
  # @param [Array<String>] coll_druids  the druids for collection object the item is a member of
  def add_coll_info doc_hash, coll_druids
    if coll_druids
      doc_hash[:collection] = []
      doc_hash[:collection_with_title] = []
      
      coll_druids.each { |coll_druid|  
        cache_coll_title coll_druid
        cache_item_formats_for_collection coll_druid, doc_hash[:format]
        cache_display_type_for_collection coll_druid, doc_hash[:display_type]
        if coll_catkey
          doc_hash[:collection] << coll_catkey
        else
          doc_hash[:collection] << coll_druid
        end
        doc_hash[:collection_with_title] << "#{coll_druid}-|-#{coll_druid_2_title_hash[coll_druid]}"
      } 
    end
  end
  
  # @return [String] The collection object catkey or nil if none exists
  def coll_catkey
    @coll_catkey ||= coll_sdb.catkey
  end
  
  # @return [SolrDocBuilder] a SolrDocBuilder object for the collection per coll_druid_from_config
  def coll_sdb
    @coll_sdb ||= SolrDocBuilder.new(coll_druid_from_config, harvestdor_client, logger)
  end
  
  # return String indicating the druid of a collection object, or nil if there is no collection druid
  # @return [String] The collection object druid or nil if none exists  (e.g. ab123cd1234)
  def coll_druid_from_config
    @coll_druid_from_config ||= begin
      druid = nil
      if config[:default_set].include? "is_member_of_collection_"
        druid = config[:default_set].gsub("is_member_of_collection_",'')
      end
      druid
    end
  end

  # cache the coll title so we don't have to look it up more than once
  def cache_coll_title coll_druid
    if !coll_druid_2_title_hash.keys.include? coll_druid
      coll_druid_2_title_hash[coll_druid] = identity_md_obj_label(coll_druid)
    end
  end
  
# FIXME:  move to public_xml_fields???
  # given a druid, get its objectLabel from its purl page identityMetadata
  # @param [String] druid, e.g. ab123cd4567
  # @return [String] the value of the <objectLabel> element in the identityMetadata for the object
  def identity_md_obj_label druid
    ng_imd = harvestdor_client.identity_metadata druid
    logger.error("#{@druid} (collection) missing identityMetadata") if !ng_imd
    ng_imd.xpath('identityMetadata/objectLabel').text
  end
  
  # cache the format(s) of this (item) object with a collection, so when the collection rec
  # is being indexed, it can get all of the formats of the members
  def cache_item_formats_for_collection coll_druid, item_formats
    if item_formats
      if item_formats.kind_of?(Array)
        item_formats.each do |item_format|
          add_to_coll_formats_from_item coll_druid, item_format
        end
      else
        add_to_coll_formats_from_item coll_druid, item_formats
      end
    end
  end

  # add a format to the coll_formats_from_items array if it isn't already there
  # @param <String> format a single format as a String
  def add_to_coll_formats_from_item coll_druid, format
    coll_formats_from_items[coll_druid] ||= [format]
    coll_formats_from_items[coll_druid] << format if !coll_formats_from_items[coll_druid].include? format
  end

  # cache the display_type of this (item) object with a collection, so when the collection rec
  # is being indexed, it can get all of the display_types of the members
  def cache_display_type_for_collection coll_druid, display_type
    if display_type && display_type.instance_of?(String)
      add_to_coll_display_types_from_item coll_druid, display_type
    end
  end

  # add a display_type to the coll_display_types_from_items array if it isn't already there
  # @param <String>  display_type a single display_type as a String
  def add_to_coll_display_types_from_item coll_druid, display_type
    coll_display_types_from_items[coll_druid] ||= [display_type]
    coll_display_types_from_items[coll_druid] << display_type if !coll_display_types_from_items[coll_druid].include? display_type
  end

  # called by indexing script (in bin directory)
  # @return [boolean] true if the collection has a catkey
  def collection_is_mergable?
    if coll_catkey
      logger.info "Collection #{coll_druid_from_config} is being merged with cat key #{coll_catkey}"
    end
    false
  end
  
  # cache collection titles so each item doesn't need to look it up -- we only look it up once per harvest.
  # collection title is from the objectLabel from the collection record's identityMetadata
  # @return [Hash<String, String>] collection druids as keys, and collection title as value
  def coll_druid_2_title_hash
    @coll_druid_2_title_hash ||= {}
  end

  # cache formats from each item so we have this info for indexing collection record 
  # @return [Hash<String, Array<String>>] collection druids as keys, array of item formats as values
  def coll_formats_from_items
    @coll_formats_from_items ||= {}
  end
  
  # cache display_type from each item so we have this info for indexing collection record 
  # @return [Hash<String, Array<String>>] collection druids as keys, array of item display_types as values
  def coll_display_types_from_items
    @coll_display_types_from_items ||= {}
  end

  # validate fields that should be in hash for any item object in SearchWorks Solr
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def validate_item druid, doc_hash
    result = validate_gdor_fields druid, doc_hash
    result << "#{druid} missing collection of harvest\n" if !doc_hash.field_present?(:collection, coll_druid_from_config)
    result << "#{druid} missing collection_with_title (or collection #{coll_druid_from_config} is missing title)\n" if !doc_hash.field_present?(:collection_with_title, Regexp.new("#{coll_druid_from_config}-\\|-.+"))
    result << "#{druid} missing file_id(s)\n" if !doc_hash.field_present?(:file_id)
    result
  end
  
  # validate fields that should be in hash for any collection object in SearchWorks Solr
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def validate_collection druid, doc_hash
    result = validate_gdor_fields druid, doc_hash
    result << "#{druid} missing collection_type 'Digital Collection'\n" if !doc_hash.field_present?(:collection_type, 'Digital Collection')
    result
  end

  # validate fields that should be in hash for every gryphonDOR object in SearchWorks Solr
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def validate_gdor_fields druid, doc_hash
    result = []
    result << "#{druid} missing druid field\n" if !doc_hash.field_present?(:druid, druid)
    result << "#{druid} missing url_fulltext for purl\n" if !doc_hash.field_present?(:url_fulltext, "#{config.purl}/#{druid}")
    result << "#{druid} missing access_facet 'Online'\n" if !doc_hash.field_present?(:access_facet, 'Online')
    result << "#{druid} missing or bad display_type, possibly caused by unrecognized @type attribute on <contentMetadata>\n" if !doc_hash.field_present?(:display_type, /(file)|(image)|(media)|(book)/)
    result
  end
  
  # count the number of records in solr for this collection (and the collection record itself)
  #  and check for a purl in the collection record
  def num_found_in_solr
    @num_found_in_solr ||= begin
      params = {:fl => 'id', :rows => 1000}
      coll_rec_id = coll_catkey ? coll_catkey : coll_druid_from_config
      params[:fq] = "collection:\"#{coll_rec_id}\""
      params[:start] ||= 0
      resp = solr_client.get 'select', :params => params
      num_found = resp['response']['numFound'].to_i

      # get the collection record too
      params.delete(:fq)
      params[:fl] = 'id, url_fulltext'
      params[:qt] = 'document'
      params[:id] = coll_rec_id
      resp = solr_client.get 'select', :params => params
      resp['response']['docs'].each do |doc|
        if doc['url_fulltext'] and doc['url_fulltext'].to_s.include?('http://purl.stanford.edu/' + doc['id'])
          num_found += 1
        end
      end
      num_found
    end
  end

  # create messages about various record counts
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def record_count_msgs
    @record_count_msgs ||= begin
      msgs = []
      if @oai_harvest_count > 0
        msgs << "OAI Records harvested count: #{@oai_harvest_count}"
      elsif @whitelist_count > 0
        msgs << "Whitelist count: #{@whitelist_count}"
      end
      if @oai_harvest_count == 0 && @whitelist_count == 0
        msgs << "NOTE:  No item records harvested from OAI or on whitelist: this could be a problem!"
      end

      msgs << "Successful count: #{@success_count}"
      msgs << "Records verified in solr (items + coll record): #{num_found_in_solr}"
      if num_found_in_solr != @success_count
        msgs << "NOTE:  Success Count and Solr count don't match: this might be a problem!"
      end

      msgs << "Error count: #{@error_count}"
      msgs << "Retry count: #{@retries}"  # currently useless due to bug in harvestdor-indexer 0.0.12
      msgs << "Total records processed: #{@success_count + @error_count}"
      msgs
    end
  end

  # log details about the results of indexing
  def log_results
    record_count_msgs.each { |msg|  
      logger.info msg
    }
    total_objects = @success_count + @error_count
    logger.info("Avg solr commit time per object (successful): #{(@total_time_to_solr/@success_count).round(2)} seconds") unless (@total_time_to_solr == 0 || @success_count == 0)
    logger.info("Avg solr commit time per object (all): #{(@total_time_to_solr/total_objects).round(2)} seconds") unless (@total_time_to_solr == 0 || total_objects == 0)
    logger.info("Avg parse time per object (successful): #{(@total_time_to_parse/@success_count).round(2)} seconds") unless (@total_time_to_parse == 0 || @success_count == 0)
    logger.info("Avg parse time per object (all): #{(@total_time_to_parse/total_objects).round(2)} seconds") unless (@total_time_to_parse == 0 || total_objects == 0)
    logger.info("Avg complete index time per object (successful): #{(@total_time/@success_count).round(2)} seconds") unless (@total_time == 0 || @success_count == 0)
    logger.info("Avg complete index time per object (all): #{(@total_time/total_objects).round(2)} seconds") unless (@total_time == 0 || total_objects == 0)
  end

  # email the results of indexing if we are on one of the harvestdor boxes
  def email_results
    require 'socket'
    if Socket.gethostname.index("harvestdor")
      to_email = config.notification ? config.notification : 'gdor-indexing-notification@lists.stanford.edu'

      body = ""
      body += record_count_msgs.join("\n") + "\n"
      body += "\n"
      body += "full log is at gdor_indexer/shared/#{config.log_dir}/#{config.log_name} on #{Socket.gethostname}"
      body += "\n"      
      body += @validation_messages.join("\n") + "\n"

      opts = {}
      opts[:subject] = "#{config.log_name.chomp('.log')} into Solr server #{config[:solr][:url]} is finished"
      opts[:body] = body
      begin
        send_email(to_email, opts)
      rescue
        logger.error('Failed to send email notification!')
      end
    end
  end

  def send_email(to, opts = {})
    opts[:server]     ||= 'localhost'
    opts[:from]       ||= 'gryphondor@stanford.edu'
    opts[:from_alias] ||= 'gryphondor'
    opts[:subject]    ||= "default subject"
    opts[:body]       ||= "default message body"
    mail = Mail.new do
      from    opts[:from]
      to      to
      subject opts[:subject]
      body    opts[:body]
    end
    mail.deliver!
  end

end
