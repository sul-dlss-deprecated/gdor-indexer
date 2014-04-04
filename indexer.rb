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
# Base class to harvest from DOR via harvestdor gem
class Indexer < Harvestdor::Indexer

  def initialize yml_path, solr_config_path, options = {}
    @success_count = 0
    @error_count = 0
    @total_time_to_solr = 0
    @total_time_to_parse = 0
    @retries = 0
    @yml_path = yml_path
    @validation_messages = ''
    solr_config = YAML.load_file(solr_config_path) if solr_config_path && File.exists?(solr_config_path)
    Indexer.config.configure(YAML.load_file(yml_path)) if yml_path && File.exists?(yml_path)
    Indexer.config.configure options 
    Indexer.config[:solr] = {:url => solr_config["solr"]["url"], :read_timeout => 3600, :open_timeout => 3600}
    yield(Indexer.config) if block_given?
  end

  def self.config
    @@config ||= Confstruct::Configuration.new()
  end
  def logger
    @logger ||= load_logger(Indexer.config.log_dir ||= 'logs', Indexer.config.log_name)
  end
  def retries
    @retries
  end
  def errors
    @errors
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
        druids.threach(3) { |druid| index_item druid }
      else
        whitelist.threach(3) { |druid| index_item druid }
      end
      index_coll_obj_per_config
    end
    
    @total_time = elapsed_time(start_time)
    logger.info("Finished harvest_and_index at #{Time.now}: final Solr commit returned")
    logger.info("Total elapsed time for harvest and index: #{(@total_time/60.0)} minutes")

    if !nocommit && coll_sdb.coll_object?
      logger.info("Beginning Commit.")
      solr_client.commit
      count_recs_in_solr
    elsif nocommit
      logger.info("Skipping commit per nocommit flag")
    end

    log_results
    email_results
  end
  
  # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.  
  #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
  def index_item druid
    if blacklist.include?(druid)
      logger.info("#{druid} is on the blacklist and will have no Solr doc created")
    else
      logger.info "indexing item #{druid}"
      begin
        sdb = SolrDocBuilder.new(druid, harvestdor_client, logger)
        doc_hash = sdb.doc_hash
        add_coll_info doc_hash, sdb.coll_druids_from_rels_ext # defined in public_xml_fields
        sdb.validate.each do |msg|
          @validation_messages += msg + "\n"
        end

        solr_add(doc_hash, druid)
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
      if coll_catkey
        logger.debug "Merging collection object #{coll_druid_from_config} into #{coll_catkey}"
        fields_to_add = {
          :url_fulltext => "http://purl.stanford.edu/#{coll_druid_from_config}",
          :access_facet => 'Online',
          :collection_type => 'Digital Collection'
        }
        RecordMerger.merge_and_index(coll_catkey, fields_to_add)
      else
        logger.info "Indexing collection object #{coll_druid_from_config}"
        doc_hash = coll_sdb.doc_hash
        doc_hash[:collection_type] = 'Digital Collection'
        # add item formats
        addl_formats = coll_formats_from_items[coll_druid_from_config] # guaranteed to be Array or nil
        if addl_formats && !addl_formats.empty?
          addl_formats.concat(doc_hash[:format]) if doc_hash[:format] # doc_hash[:format] guaranteed to be Array
          doc_hash[:format] = addl_formats.uniq
        end
        coll_sdb.validate.each do |msg|
          @validation_messages += msg + "\n"
        end
        solr_add(doc_hash, coll_druid_from_config) unless coll_druid_from_config.nil?
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
      if Indexer.config[:default_set].include? "is_member_of_collection_"
        druid = Indexer.config[:default_set].gsub("is_member_of_collection_",'')
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
  
  # cache the format(s) of this object with a collection, so when the collection rec
  # is being indexed, it gets all of the formats of the members
  def cache_item_formats_for_collection coll_druid, item_formats
    coll_formats_from_items[coll_druid] ||= []
    if item_formats
      if item_formats.kind_of?(Array)
        item_formats.each do |item_format|
          add_to_coll_formats_from_items coll_druid, item_format
        end
      else
        add_to_coll_formats_from_items coll_druid, item_formats
      end
    end
  end

  # add a format to the coll_formats_from_items array if it isn't already there
  # @param <Object> a single format as a String or an Array of Strings for multiple formats
  def add_to_coll_formats_from_items coll_druid, format
    @coll_formats_from_items[coll_druid] << format if !@coll_formats_from_items[coll_druid].include? format
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
  
  def solr_client
    @solr_client ||= RSolr.connect(Indexer.config.solr.to_hash)
  end

  # validate fields that should be in hash for any item object in SearchWorks Solr
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def validate_item druid, doc_hash
    result = validate_gdor_fields druid, doc_hash
    result << "#{druid} missing collection of harvest\n" if !doc_hash.field_present?(:collection, coll_druid_from_config)
    result << "#{druid} missing collection_with_title (or collection #{coll_druid_from_config} is missing title)\n" if !doc_hash.field_present?(:collection_with_title, Regexp.new("#{coll_druid_from_config}-\\|-.+"))
    result << "#{druid} missing file_id\n" if !doc_hash.field_present?(:file_id)
#    result << validate_mods druid, doc_hash
    result
  end
  
  # validate fields that should be in hash for any collection object in SearchWorks Solr
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def validate_collection druid, doc_hash
    result = validate_gdor_fields druid, doc_hash
    result << "#{druid} missing collection_type 'Digital Collection'\n" if !doc_hash.field_present?(:collection_type, 'Digital Collection')
#    result << validate_mods druid, doc_hash
    result
  end

  # validate fields that should be in hash for every gryphonDOR object in SearchWorks Solr
  # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
  def validate_gdor_fields druid, doc_hash
    result = []
    result << "#{druid} missing druid field\n" if !doc_hash.field_present?(:druid, druid)
    result << "#{druid} missing url_fulltext for purl\n" if !doc_hash.field_present?(:url_fulltext, "#{Indexer.config.purl}/#{druid}")
    result << "#{druid} missing access_facet 'Online'\n" if !doc_hash.field_present?(:access_facet, 'Online')
    result << "#{druid} missing or bad display_type, possibly caused by unrecognized @type attribute on <contentMetadata>\n" if !doc_hash.field_present?(:display_type, /(file)|(image)|(media)|(book)/)
    result
  end
  
  # count the number of records in solr for this collection (and the collection record itself)
  #  and check for a purl in the collection record
  def count_recs_in_solr
    params = {:fl => 'id', :rows => 1000}
    coll_rec_id = coll_catkey ? coll_catkey : coll_druid_from_config
    params[:fq] = "collection:\"#{coll_rec_id}\""
    params[:start] ||= 0
    resp = solr_client.get 'select', :params => params
    @found_in_solr_count = resp['response']['numFound'].to_i

    # get the collection record too
    params.delete(:fq)
    params[:fl] = 'id, url_fulltext'
    params[:qt] = 'document'
    params[:id] = coll_rec_id
    resp = solr_client.get 'select', :params => params
    resp['response']['docs'].each do |doc|
      if doc['url_fulltext'] and doc['url_fulltext'].to_s.include?('http://purl.stanford.edu/' + doc['id'])
        @found_in_solr_count += 1
      end
    end
    @found_in_solr_count
  end

  # log details about the results of indexing
  def log_results
    total_objects = @success_count + @error_count
    logger.info("Avg solr commit time per object (successful): #{@total_time_to_solr/@success_count} seconds") unless (@total_time_to_solr == 0 || @success_count == 0)
    logger.info("Avg solr commit time per object (all): #{@total_time_to_solr/total_objects} seconds") unless (@total_time_to_solr == 0 || @error_count == 0 || total_objects == 0)
    logger.info("Avg parse time per object (successful): #{@total_time_to_parse/@success_count} seconds") unless (@total_time_to_parse == 0 || @success_count == 0)
    logger.info("Avg parse time per object (all): #{@total_time_to_parse/total_objects} seconds") unless (@total_time_to_parse == 0 || @error_count == 0 || total_objects == 0)
    logger.info("Avg complete index time per object (successful): #{@total_time/@success_count} seconds") unless (@success_count == 0)
    logger.info("Avg complete index time per object (all): #{@total_time/total_objects} seconds") unless (@error_count == 0 || total_objects == 0)
    logger.info("Successful count: #{@success_count}")
    if @found_in_solr_count == @success_count
      logger.info("Records verified in solr: #{@found_in_solr_count}")
    else
      logger.info("Success Count and Solr count dont match, this might be a problem! Records verified in solr: #{@found_in_solr_count}")
    end
    logger.info("Error count: #{@error_count}")
    logger.info("Retry count: #{@retries}")
    logger.info("Total records processed: #{total_objects}")
  end
  
  # email the results of indexing
  def email_results
    to_email = Indexer::config.notification ? Indexer::config.notification : 'gdor-indexing-notification@lists.stanford.edu'

    total_objects = @success_count + @error_count
    
    body = "Successful count: #{@success_count}\n"
    if @found_in_solr_count == @success_count
      body += "Records verified in solr: #{@found_in_solr_count}\n"
    else
      body += "Success Count and Solr count dont match, this might be a problem!\nRecords verified in solr: #{@found_in_solr_count}\n"
    end
    body += "Error count: #{@error_count}\n"
    body += "Retry count: #{@retries}\n"
    body += "Total records processed: #{total_objects}\n"
    body += "\n"
    require 'socket'
    body += "full log is at gdor_indexer/shared/#{Indexer.config.log_dir}/#{Indexer.config.log_name} on #{Socket.gethostname}"
    body += "\n"
    body += @validation_messages

    opts = {}
    opts[:subject] = "#{Indexer.config.log_name} into Solr server #{Indexer.config[:solr][:url]} is finished"
    opts[:body] = body
    begin
      send_email(to_email, opts)
    rescue
      logger.error('Failed to send email notification!')
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


class Hash  

  # looks for non-empty existence of field when exp_val is nil;
  # when exp_val is a String, looks for matching value as a String or as a member of an Array
  # when exp_val is a Regexp, looks for String value that matches, or Array with a String member that matches
  # @return true if the field is non-trivially present in the hash, false otherwise
  def field_present? field, exp_val = nil
    if self[field] && self[field].length > 0 
      actual = self[field]
      return true if exp_val == nil && ( !actual.instance_of?(Array) || actual.index { |s| s.length > 0 } )
      if exp_val.instance_of?(String)
        if actual.instance_of?(String)
          return true if actual == exp_val
        elsif actual.instance_of?(Array)
          return true if actual.include? exp_val
        end
      elsif exp_val.instance_of?(Regexp)
        if actual.instance_of?(String)
          return true if exp_val.match(actual)
        elsif actual.instance_of?(Array)
          return true if actual.index { |s| exp_val.match(s) }
        end
      end
    end
    false
  end
  
end
