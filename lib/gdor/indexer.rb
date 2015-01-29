# external gems
require 'confstruct'
require 'harvestdor-indexer'
require 'rsolr'
require 'mail'
require 'dor-fetcher'
require 'hooks'
require 'active_support/core_ext/array/extract_options'

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
    require 'gdor/indexer/version'
    require 'gdor/indexer/solr_doc_hash'
    require 'gdor/indexer/solr_doc_builder'
    require 'gdor/indexer/nokogiri_xml_node_mixin' if defined? JRUBY_VERSION

    attr_accessor :harvestdor
    attr_reader :config, :druids_failed_to_ix

    class <<self
      attr_accessor :config
    end

    # Initialize with configuration files
    # @param yml_path [String] /path/to
    # @param options [Hash]
    def initialize *args
      options = args.extract_options!
      yml_path = args.first

      @success_count = 0
      @error_count = 0
      @total_time_to_solr = 0
      @total_time_to_parse = 0
      @retries = 0
      @druids_failed_to_ix = []
      @validation_messages = []
      @config ||= Confstruct::Configuration.new options
      @config.configure(YAML.load_file(yml_path)) if yml_path && File.exists?(yml_path)
      yield @config if block_given?
      @harvestdor = Harvestdor::Indexer.new @config
    end

    def logger
      harvestdor.logger
    end

    def solr_client
      harvestdor.solr
    end

    def metrics
      harvestdor.metrics
    end

    # per this Indexer's config options
    #  harvest the druids via DorFetcher
    #   create a Solr document for each druid suitable for SearchWorks and
    #   write the result to the SearchWorks Solr index
    #  (all members of the collection + coll rec itself)
    def harvest_and_index(nocommit = nil)
      if nocommit.nil?
        nocommit = config.nocommit
      end

      start_time=Time.now
      logger.info("Started harvest_and_index at #{start_time}")

      harvestdor.each_resource(in_threads: 3) do |resource|
        index_with_exception_handling resource
      end
      
      unless nocommit
        logger.info("Beginning Commit.")
        solr_client.commit!
        logger.info("Finished Commit.")
      else
        logger.info("Skipping commit per nocommit flag")
      end

      @total_time = elapsed_time(start_time)
      logger.info("Finished harvest_and_index at #{Time.now}")
      logger.info("Total elapsed time for harvest and index: #{(@total_time/60).round(2)} minutes")

      log_results
      email_results
    end

    def index resource
      doc_hash = solr_document resource
      run_hook :before_index, resource, doc_hash
      solr_client.add(doc_hash)
    end

    def solr_document resource    
      if resource.collection?
        collection_solr_document resource
      else
        item_solr_document resource
      end
    end

    def index_with_exception_handling resource
      begin
        index resource
      rescue => e
        @error_count += 1
        @druids_failed_to_ix << resource.druid
        logger.error "Failed to index item #{resource.druid}: #{e.message} #{e.backtrace}"
        raise e
      end
    end

    # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.
    #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
    def item_solr_document resource
      sdb = GDor::Indexer::SolrDocBuilder.new(resource, logger)

      fields_to_add = GDor::Indexer::SolrDocHash.new({
        :druid => resource.bare_druid,
        :url_fulltext => "http://purl.stanford.edu/#{resource.bare_druid}",
        :access_facet => 'Online',
        :display_type => sdb.display_type,  # defined in public_xml_fields
        :building_facet => 'Stanford Digital Repository'  # INDEX-53 add building_facet = Stanford Digital Repository here for item
      })
      fields_to_add[:file_id] = sdb.file_ids unless !sdb.file_ids  # defined in public_xml_fields

      logger.info "indexing item #{resource.bare_druid}"
      doc_hash = sdb.doc_hash
      doc_hash.combine fields_to_add
      add_coll_info doc_hash, resource.collections # defined in public_xml_fields
      validation_messages = fields_to_add.validate_item(config)
      validation_messages.concat doc_hash.validate_mods(config)
      @validation_messages.concat(validation_messages)
      doc_hash.to_h
    end

    # Create Solr document for the collection druid suitable for SearchWorks
    #  and write the result to the SearchWorks Solr Index
    # @param [String] druid
    def collection_solr_document resource
      coll_sdb = GDor::Indexer::SolrDocBuilder.new(resource, logger)

      fields_to_add = GDor::Indexer::SolrDocHash.new({
        :druid => resource.bare_druid,
        :url_fulltext => "http://purl.stanford.edu/#{resource.bare_druid}",
        :access_facet => 'Online',
        :collection_type => 'Digital Collection',
        :display_type => coll_display_types_from_items(resource),
        :format_main_ssim => 'Archive/Manuscript',  # per INDEX-12, add this to all collection records (does not add dups)
        :format => 'Manuscript/Archive',  # per INDEX-144, add this to all collection records (does not add dups)
        :building_facet => 'Stanford Digital Repository'  # INDEX-53 add building_facet = Stanford Digital Repository here for collection
      })

      logger.info "Indexing collection object #{resource.druid} (unmerged)"
      doc_hash = coll_sdb.doc_hash
      doc_hash.combine fields_to_add
      validation_messages = doc_hash.validate_collection(config)
      validation_messages.concat doc_hash.validate_mods(config)
      @validation_messages.concat(validation_messages)
      doc_hash.to_h
    end

    # add coll level data to this solr doc and/or cache collection level information
    # @param [Hash] Hash representing the Solr document (for an item)
    # @param [Array<String>] coll_druids  the druids for collection object the item is a member of
    def add_coll_info doc_hash, collections
      if collections
        doc_hash[:collection] = []
        doc_hash[:collection_with_title] = []

        collections.each { |collection|
          cache_display_type_for_collection collection, doc_hash[:display_type]
          doc_hash[:collection] << collection.bare_druid
          doc_hash[:collection_with_title] << "#{collection.bare_druid}-|-#{coll_title(collection)}"
        }
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
    def coll_display_types_from_items resource
      @collection_display_types ||= {}
      @collection_display_types[resource.druid] ||= Set.new
    end

    # cache the display_type of this (item) object with a collection, so when the collection rec
    # is being indexed, it can get all of the display_types of the members
    def cache_display_type_for_collection resource, display_type
      if display_type && display_type.instance_of?(String)
        coll_display_types_from_items(resource) << display_type
      end
    end

    # count the number of records in solr for this collection (and the collection record itself)
    #  and check for a purl in the collection record
    def num_found_in_solr fqs
      params = {:fl => 'id', :rows => 1000}
      params[:fq] = fqs.map { |k,v| "#{k}:\"#{v}\""}
      params[:start] ||= 0
      resp = solr_client.client.get 'select', :params => params
      num_found = resp['response']['numFound'].to_i

      if fqs.has_key? :collection
        num_found += num_found_in_solr id: fqs[:collection]
      end

      num_found
    end

    # create messages about various record counts
    # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
    def record_count_msgs
      @record_count_msgs ||= begin
        msgs = []
        msgs << "Successful count (items + coll record indexed w/o error): #{metrics.success_count}"

        harvestdor.resources.select { |x| x.collection? }.each do |collection|
          solr_count = num_found_in_solr(collection: collection.bare_druid)
          msgs << "#{config.harvestdor.log_name.chomp('.log')} indexed coll record is: #{collection.druid}\n"
          msgs << "coll title: #{coll_title(collection)}\n"
          msgs << "Solr query for items: #{config[:solr][:url]}/select?fq=collection:#{collection.bare_druid}&fl=id,title_245a_display\n"
          msgs << "Records verified in solr for collection #{collection.druid} (items + coll record): #{num_found_in_solr collection: collection.bare_druid}"
          if (collection.items.length > solr_count)
            msgs << "WARNING: Expected #{collection.druid} to contain #{collection.items.length} items, but only found #{solr_count}."
            msgs << "These are the druids that did not get indexed:"
            msgs << "#{@druids_failed_to_ix}"
          end
        end

        msgs << "Error count (items + coll record w any error; may have indexed on retry if it was a timeout): #{metrics.error_count}"
  #      msgs << "Retry count: #{@retries}"  # currently useless due to bug in harvestdor-indexer 0.0.12
        msgs << "Total records processed: #{metrics.total}"
        msgs
      end
    end

    # log details about the results of indexing
    def log_results
      record_count_msgs.each { |msg|
        logger.info msg
      }
      logger.info("Avg solr commit time per object (successful): #{(@total_time_to_solr/metrics.success_count).round(2)} seconds") unless metrics.success_count == 0
      logger.info("Avg solr commit time per object (all): #{(@total_time_to_solr/metrics.total).round(2)} seconds") unless metrics.total == 0
      logger.info("Avg parse time per object (successful): #{(@total_time_to_parse/metrics.success_count).round(2)} seconds") unless metrics.success_count == 0
      logger.info("Avg parse time per object (all): #{(@total_time_to_parse/metrics.total).round(2)} seconds") unless metrics.total == 0
      logger.info("Avg complete index time per object (successful): #{(@total_time/metrics.success_count).round(2)} seconds") unless metrics.success_count == 0
      logger.info("Avg complete index time per object (all): #{(@total_time/metrics.total).round(2)} seconds") unless metrics.total == 0
    end

    def email_report_body
      
      body = ""
      
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
      
    end

    # email the results of indexing if we are on one of the harvestdor boxes
    def email_results
      if config.notification
        to_email = config.notification

        opts = {}
        opts[:subject] = "#{config.harvestdor.log_name.chomp('.log')} into Solr server #{config[:solr][:url]} is finished"
        opts[:body] = email_report_body
        begin
          send_email(to_email, opts)
        rescue => e
          logger.error('Failed to send email notification!')
          logger.error(e)
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
  end
end