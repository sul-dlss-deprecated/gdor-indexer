# external gems
require 'confstruct'
require 'harvestdor-indexer'
require 'rsolr'
require 'mail'
require 'threach'
require 'dor-fetcher'
require 'hooks'

# stdlib
require 'logger'
require 'net/smtp'
require 'set'

# Base class to harvest from DOR via harvestdor gem
module GDor
  class Indexer

    include Hooks

    define_hooks :before_index, :before_merge

    # local files
    require 'gdor/indexer/solr_doc_hash'
    require 'gdor/indexer/solr_doc_builder'
    require 'gdor/indexer/nokogiri_xml_node_mixin' if defined? JRUBY_VERSION
    require 'gdor/indexer/record_merger'

    attr_accessor :harvestdor
    attr_reader :druid_item_array, :config

    class <<self
      attr_accessor :config
    end

    # Initialize with configuration files
    # @param yml_path [String] /path/to
    def initialize yml_path, client_config_path, solr_config_path, options = {}
      @dor_fetcher_count = 0
      @whitelist_count = 0
      @success_count = 0
      @error_count = 0
      @total_time_to_solr = 0
      @total_time_to_parse = 0
      @retries = 0
      @yml_path = yml_path
      @druids_failed_to_ix = []
      @validation_messages = []
      @druid_item_array = []   # Local cache of items returned by dor-fetcher-service
      @collection = File.basename(yml_path, ".yml")
      solr_config = YAML.load_file(solr_config_path) if solr_config_path && File.exists?(solr_config_path)
      @config ||= Confstruct::Configuration.new()
      @config.configure(YAML.load_file(yml_path)) if yml_path && File.exists?(yml_path)
      # Set merge_policy to never to remove item-level merge
      @config[:merge_policy] = "never"
      yield @config if block_given?
      self.class.config = @config
      @harvestdor = Harvestdor::Indexer.new @config
    end

    def harvestdor_client
      harvestdor.harvestdor_client
    end

    def logger
      harvestdor.logger
    end

    def solr_client
      harvestdor.solr
    end

    # per this Indexer's config options
    #  harvest the druids via DorFetcher
    #   create a Solr document for each druid suitable for SearchWorks and
    #   write the result to the SearchWorks Solr index
    #  (all members of the collection + coll rec itself)
    def harvest_and_index(nocommit = false)
      start_time=Time.now
      logger.info("Started harvest_and_index at #{start_time}")

      harvestdor.each_resource(in_threads: 3) do |resource|
        index_with_exception_handling resource
      end
      
      if !nocommit && coll_sdb.collection?
        logger.info("Beginning Commit.")
        solr_client.commit!
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

    def index resource
      if resource.collection?
        index_coll_obj_per_config resource
      else
        index_item_with_exception_handling resource
      end
    end

    def index_with_exception_handling resource
      begin
        index resource
      rescue => e
        @error_count += 1
        @druids_failed_to_ix << resource.druid
        logger.error "Failed to index item #{resource.druid}: #{e.message} #{e.backtrace}"
      end
    end

    # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.
    #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
    def index_item resource
      druid = resource.druid.split(':').last  # drop the druid prefix

      sdb = GDor::Indexer::SolrDocBuilder.new(resource, logger)

      fields_to_add = GDor::Indexer::SolrDocHash.new({
        :druid => druid,
        :url_fulltext => "http://purl.stanford.edu/#{druid}",
        :access_facet => 'Online',
        :display_type => sdb.display_type,  # defined in public_xml_fields
        :building_facet => 'Stanford Digital Repository'  # INDEX-53 add building_facet = Stanford Digital Repository here for item
      })
      fields_to_add[:file_id] = sdb.file_ids unless !sdb.file_ids  # defined in public_xml_fields

      ckey = sdb.catkey
      if ckey
        if config.merge_policy == 'never'
          logger.warn("#{druid} to be indexed from MODS; has ckey #{ckey} but merge_policy is 'never'")
          merged = false
        else
          add_coll_info fields_to_add, resource.collections # defined in public_xml_fields
          @validation_messages = fields_to_add.validate_item(config)
          require 'gdor/indexer/record_merger'
          run_hook :before_merge, sdb, fields_to_add
          merged = record_merger.merge_and_index(ckey, fields_to_add)
          if merged
            logger.info "item #{druid} merged into #{ckey}"
            @success_count += 1
          else
            if config.merge_policy == 'always'
              logger.error("#{druid} NOT INDEXED:  MARC record #{ckey} not found in SW Solr index (may be shadowed in Symphony) and merge_policy set to 'always'")
              @error_count += 1
            else
              logger.error("#{druid} to be indexed from MODS:  MARC record #{ckey} not found in SW Solr index (may be shadowed in Symphony)")
            end
          end
        end
      end

      if !ckey && config.merge_policy == 'always'
        logger.error("#{druid} NOT INDEXED:  no ckey found and merge_policy set to 'always'")
        @error_count += 1
      elsif !ckey || ( !merged && config.merge_policy != 'always' )
        logger.info "indexing item #{druid} (unmerged)"
        doc_hash = sdb.doc_hash
        doc_hash.combine fields_to_add
        add_coll_info doc_hash, resource.collections # defined in public_xml_fields
        @validation_messages = fields_to_add.validate_item(config)
        @validation_messages.concat doc_hash.validate_mods(config)
        run_hook :before_index, sdb, doc_hash
        solr_client.add(doc_hash)
        @success_count += 1
      end
    end

    # Create Solr document for the collection druid suitable for SearchWorks
    #  and write the result to the SearchWorks Solr Index
    # @param [String] druid
    def index_coll_obj_per_config resource
      coll_druid = resource.druid.split(':').last
      coll_sdb = GDor::Indexer::SolrDocBuilder.new(resource, logger)
      coll_catkey = coll_sdb.catkey

      # we have already affirmed that coll_druid_from_config is a collection record in harvest_and_index method
      begin
        fields_to_add = GDor::Indexer::SolrDocHash.new({
          :druid => coll_druid,
          :url_fulltext => "http://purl.stanford.edu/#{coll_druid}",
          :access_facet => 'Online',
          :collection_type => 'Digital Collection',
          :display_type => coll_display_types_from_items(coll_druid),
          :format_main_ssim => 'Archive/Manuscript',  # per INDEX-12, add this to all collection records (does not add dups)
          :format => 'Manuscript/Archive',  # per INDEX-144, add this to all collection records (does not add dups)
          :building_facet => 'Stanford Digital Repository'  # INDEX-53 add building_facet = Stanford Digital Repository here for collection
        })
        if coll_catkey
          if config.merge_policy == 'never'
            logger.warn("#{coll_druid} to be indexed from MODS; has ckey #{coll_catkey} but merge_policy is 'never'")
            merged = false
          else
            @validation_messages = fields_to_add.validate_collection(config)
            require 'gdor/indexer/record_merger'
            run_hook :before_merge, nil, fields_to_add
            merged = record_merger.merge_and_index(coll_catkey, fields_to_add)
            if merged
              logger.info "Collection object #{coll_druid} merged into #{coll_catkey}"
              @success_count += 1
            else
              logger.error("#{coll_druid} to be indexed from MODS:  MARC record #{coll_catkey} not found in SW Solr index (may be shadowed in Symphony)")
            end
          end
        end

        if !coll_catkey || !merged
          logger.info "Indexing collection object #{coll_druid} (unmerged)"
          doc_hash = coll_sdb.doc_hash
          doc_hash.combine fields_to_add
          @validation_messages = doc_hash.validate_collection(config)
          @validation_messages.concat doc_hash.validate_mods(config)
          run_hook :before_index, nil, doc_hash
          solr_client.add(doc_hash) unless coll_druid.nil?
          @success_count += 1
        end
      rescue => e
        logger.error "Failed to index collection object #{coll_druid}: #{e.message} #{e.backtrace}"
        @error_count += 1
        @druids_failed_to_ix << coll_druid
      end
    end

    # add coll level data to this solr doc and/or cache collection level information
    # @param [Hash] Hash representing the Solr document (for an item)
    # @param [Array<String>] coll_druids  the druids for collection object the item is a member of
    def add_coll_info doc_hash, collections
      if collections
        doc_hash[:collection] = []
        doc_hash[:collection_with_title] = []

        collections.each { |collection|
          cache_display_type_for_collection collection.druid, doc_hash[:display_type]
          coll_id = coll_catkey(collection) ? coll_catkey(collection) : collection.druid
          doc_hash[:collection] << coll_id
          doc_hash[:collection_with_title] << "#{coll_id}-|-#{coll_title(collection)}"
        }
      end
    end
    
    # cache the coll title so we don't have to look it up more than once
    def coll_catkey resource
      @collection_catkeys ||= {}
      @collection_catkeys[resource.druid] ||= begin
        coll_sdb = GDor::Indexer::SolrDocBuilder.new(resource, logger)
        coll_sdb.catkey
      end
    end
    

    # cache the coll title so we don't have to look it up more than once
    def coll_title resource
      @collection_titles ||= {}
      @collection_titles[resource.druid] ||= begin
        resource.identity_md_obj_label
      end
    end
    
    # cache of display_type from each item so we have this info for indexing collection record
    # @return [Hash<String, Array<String>>] collection druids as keys, array of item display_types as values
    def coll_display_types_from_items coll_druid
      @collection_display_types ||= {}
      @collection_display_types[coll_druid] ||= Set.new
    end

    # cache the display_type of this (item) object with a collection, so when the collection rec
    # is being indexed, it can get all of the display_types of the members
    def cache_display_type_for_collection coll_druid, display_type
      if display_type && display_type.instance_of?(String)
        coll_display_types_from_items(coll_druid) << display_type
      end
    end

    # count the number of records in solr for this collection (and the collection record itself)
    #  and check for a purl in the collection record
    def num_found_in_solr coll_rec_id
      @num_found_in_solr ||= begin
        params = {:fl => 'id', :rows => 1000}
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
          if doc['url_fulltext'] and doc['url_fulltext'].to_s.include?('http://purl.stanford.edu/' + coll_rec_id)
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
        if @dor_fetcher_count > 0
          msgs << "DOR Fetcher Records harvested count (items only): #{@dor_fetcher_count}"
        elsif @whitelist_count > 0
          msgs << "Whitelist count: #{@whitelist_count}"
        end
        if @dor_fetcher_count == 0 && @whitelist_count == 0
          msgs << "WARNING:  No item records harvested using DorFetcher or on whitelist: this could be a problem!"
        end

        msgs << "Successful count (items + coll record indexed w/o error): #{@success_count}"

        harvestdor.resources.select { |x| x.collection? }.each do |collection|
          solr_count = num_found_in_solr(coll_catkey(collection) || collection.druid)
          msgs << "Records verified in solr for collection #{collection.druid} (items + coll record): #{solr_count}"
          msgs << "WARNING: Expected #{collection.druid} to contain #{collection.items.length} items, but only found #{solr_count}."
        end

        # this is wrong.
        if num_found_in_solr(harvestdor.druids.first) != @success_count
          msgs << "WARNING:  Success Count and Solr count don't match: this could be a problem!"
        end

        msgs << "Error count (items + coll record w any error; may have indexed on retry if it was a timeout): #{@error_count}"
  #      msgs << "Retry count: #{@retries}"  # currently useless due to bug in harvestdor-indexer 0.0.12
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

        harvestdor.resources.select { |x| x.collection? }.each do |collection|
          coll_rec_id = coll_catkey(collection) || collection.druid
          body += "#{config.harvestdor.log_name.chomp('.log')} indexed coll record is: #{coll_rec_id}\n"
          body += "coll title: #{coll_title(collection)}\n"
          body += "Solr query for items: #{config[:solr][:url]}/select?fq=collection:#{coll_rec_id}&fl=id,title_245a_display\n"
        end

        body += "\n" + record_count_msgs.join("\n") + "\n"

        if @druids_failed_to_ix.size > 0
          body += "\n"
          body += "records that may have failed to index (merged recs as druids, not ckeys): \n"
          body += @druids_failed_to_ix.join("\n") + "\n"
        end

        body += "\n"
        body += "full log is at gdor_indexer/shared/#{config.harvestdor.log_dir}/#{config.harvestdor.log_name} on #{Socket.gethostname}"
        body += "\n"

        body += @validation_messages.join("\n") + "\n"

        opts = {}
        opts[:subject] = "#{config.harvestdor.log_name.chomp('.log')} into Solr server #{config[:solr][:url]} is finished"
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
    
    def elapsed_time(start_time,units=:seconds)
      elapsed_seconds=Time.now-start_time
      case units
      when :seconds
        return elapsed_seconds.round(2)
      when :minutes
        return (elapsed_seconds/60.0).round(1)
      when :hours
        return (elapsed_seconds/3600.0).round(2)
      else
        return elapsed_seconds
      end 
    end

    def record_merger
      @record_merger ||= GDor::Indexer::RecordMerger.new self
    end

  end
end