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
    @logger ||= load_logger(Indexer.config.log_dir, Indexer.config.log_name)
  end
  def retries
    @retries
  end
  def errors
    @errors
  end
  
  # per this Indexer's config options 
  #  harvest the druids via OAI
  #   create a Solr document for each druid suitable for SearchWorks
  #   write the result to the SearchWorks Solr index
  def harvest_and_index(nocommit = false)
    start_time=Time.now
    
    logger.info("Started harvest_and_index at #{start_time}")
    if whitelist.empty?
      druids.threach(3) { |druid| index druid }
    else
      whitelist.threach(3) { |druid| index druid }
    end
    index_collection_druid
    total_time = elapsed_time(start_time)
    total_objects = @success_count + @error_count
    logger.info("Finished harvest_and_index at #{Time.now}: final Solr commit returned")
    logger.info("Total elapsed time for harvest and index: #{(total_time/60.0)} minutes")
    logger.info("Beginning Commit.")
    ## Commit our indexing job unless the :nocommit flag was passed
    unless nocommit
      solr_client.commit
    else
      puts "Skipping commit because :nocommit flag was passed"
    end
    verify
    logger.info("Avg solr commit time per object (successful): #{@total_time_to_solr/@success_count} seconds") unless (@total_time_to_solr == 0 || @success_count == 0)
    logger.info("Avg solr commit time per object (all): #{@total_time_to_solr/total_objects} seconds") unless (@total_time_to_solr == 0 || @error_count == 0 || total_objects == 0)
    logger.info("Avg parse time per object (successful): #{@total_time_to_parse/@success_count} seconds") unless (@total_time_to_parse == 0 || @success_count == 0)
    logger.info("Avg parse time per object (all): #{@total_time_to_parse/total_objects} seconds") unless (@total_time_to_parse == 0 || @error_count == 0 || total_objects == 0)
    logger.info("Avg complete index time per object (successful): #{total_time/@success_count} seconds") unless (@success_count == 0)
    logger.info("Avg complete index time per object (all): #{total_time/total_objects} seconds") unless (@error_count == 0 || total_objects == 0)
    logger.info("Successful count: #{@success_count}")
    if @found_in_solr_count == @success_count
      logger.info("Records verified in solr: #{@found_in_solr_count}")
    else
      logger.info("Success Count and Solr count dont match, this might be a problem! Records verified in solr: #{@found_in_solr_count}")
    end
    logger.info("Error count: #{@error_count}")
    logger.info("Retry count: #{@retries}")
    logger.info("Total records processed: #{total_objects}")
    send_notifications
  end
  
  def send_notifications
    total_objects = @success_count + @error_count
    notifications = Indexer::config.notification ? Indexer::config.notification : 'gdor-indexing-notification@lists.stanford.edu'
    subject = "#{Indexer.config.log_name} into Solr server #{Indexer.config[:solr][:url]} is ready"
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
    opts[:from_alias] = 'gryphondor'
    opts[:server] = 'localhost'
    opts[:from] = 'gryphondor@stanford.edu'
    opts[:subject] = subject
    opts[:body] = body
    begin
    send_email(notifications,opts)
    rescue
      logger.error('Failed to send email notification!')
    end
  end

  # create Solr doc for the druid and add it to Solr, unless it is on the blacklist.  
  #  NOTE: don't forget to send commit to Solr, either once at end (already in harvest_and_index), or for each add, or ...
  def index druid
    if blacklist.include?(druid)
      logger.info("Druid #{druid} is on the blacklist and will have no Solr doc created")
    else
      begin
        logger.info "indexing #{druid}"
        solr_add(sw_solr_doc(druid), druid)
        @success_count += 1
      rescue => e
        @error_count += 1
        logger.error "Failed to index #{druid}: #{e.message} #{e.backtrace}"
      end
    end
  end

  # Create a solr document for the collection druid suitable for searchworks
  # write the result to the SearchWorks Solr Index
  # @param [String] druid 
  def index_collection_druid
    coll_druid = collection_druid # cache it for this method
    if catkey
      begin
        logger.debug "Merging collection object #{coll_druid} into #{catkey}"
        RecordMerger.merge_and_index(coll_druid, catkey)
        @success_count += 1
      rescue => e
        logger.error "Failed to merge collection object #{coll_druid}: #{e.message}"
         @error_count += 1
      end
    else
      begin
        logger.debug "Indexing collection object #{coll_druid}"
        solr_client.add(sw_solr_doc(coll_druid)) unless coll_druid.nil?
        @success_count += 1
        # update DOR object's workflow datastream??   for harvest?  for indexing?
      rescue => e
        logger.error "Failed to index collection object #{collection_druid}: #{e.message}"
        @error_count += 1
      end
    end
  end

  # Create a Solr doc, as a Hash, to be added to the SearchWorks Solr index.  
  # Solr doc contents are based on the mods, contentMetadata, etc. for the druid
  # @param [String] druid, e.g. ab123cd4567
  # @param [Stanford::Mods::Record] MODS metadata as a Stanford::Mods::Record object
  # @param [Hash] Hash representing the Solr document
  def sw_solr_doc druid
    sdb = SolrDocBuilder.new(druid, harvestdor_client, logger)
    doc_hash = sdb.doc_hash
    sdb.validate.each do |msg|
      @validation_messages += msg + "\n"
    end
    doc_hash[:url_fulltext] = "#{Indexer.config.purl}/#{druid}"

    # determine collection druids and their titles and add to solr doc
    coll_druids = sdb.collection_druids
    if coll_druids
      doc_hash[:collection] = []
      doc_hash[:collection_with_title] = []
      coll_druids.each { |coll_druid|  
        # cache the collection title
        if !coll_hash.keys.include? coll_druid
          @coll_hash[coll_druid] = identity_md_obj_label(coll_druid)
        end
        
        # cache the format(s) of this object with each of its collections, so when the collection recs 
        # are being indexed, they get all of the formats of the members
        Indexer.format_hash[coll_druid] ||= []
        if doc_hash[:format]
          if doc_hash[:format].kind_of?(Array)
            doc_hash[:format].each do |format|
              Indexer.format_hash[coll_druid] << format
            end
          else
            Indexer.format_hash[coll_druid] << doc_hash[:format]
          end
        end
        
        if catkey
          doc_hash[:collection] << catkey
        else
          doc_hash[:collection] << coll_druid
        end
        
        doc_hash[:collection_with_title] << "#{coll_druid}-|-#{coll_hash[coll_druid]}"
      } # each coll_druid
    end
    doc_hash
  end
  
  # @return [boolean] true if the collection has a catkey
  def collection_is_mergable?
    if catkey
      logger.info "Collection #{collection_druid} is being merged with cat key #{catkey}"
    end
    false
  end
  
  # @return [String]The collection object catkey or nil if none exists
  def catkey
    @catkey ||= SolrDocBuilder.new(collection_druid, harvestdor_client, logger).catkey
  end
  
  # return String indicating the druid of a collection object, or nil if there is no collection druid
  # @return [Array<String>] or enumeration over it, if block is given.  (strings are druids, e.g. ab123cd1234)
  def collection_druid
    begin
      if Indexer.config[:default_set].include? "is_member_of_collection_"
        return Indexer.config[:default_set].gsub("is_member_of_collection_",'')
      else
        return nil
      end
    end
  end

  # given a druid, get its objectLabel from its purl page identityMetadata
  # @param [String] druid, e.g. ab123cd4567
  # @return [String] the value of the <objectLabel> element in the identityMetadata for the object
  def identity_md_obj_label druid
    ng_imd = harvestdor_client.identity_metadata druid
    # TODO: create nom-xml terminology for identityMetadata in harvestdor?
    ng_imd.xpath('identityMetadata/objectLabel').text
  end
  
  #count the number of records in solr for this collection (and the collection record itself), to compare against the number the indexer thinks it indexed.
  def verify
    params = {:fl => 'id', :rows => 1000}
    coll_rec_id = catkey ? catkey : collection_druid
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
    puts resp.inspect
    resp['response']['docs'].each do |doc|
      if doc['url_fulltext'] and doc['url_fulltext'].to_s.include?('http://purl.stanford.edu/' + doc['id'])
        @found_in_solr_count += 1
      end
    end
    @found_in_solr_count
  end

  def send_email(to, opts = {})
    opts[:server]      ||= 'localhost'
    opts[:from]        ||= 'email@example.com'
    opts[:from_alias]  ||= 'Example Emailer'
    opts[:subject]     ||= "You need to see this"
    opts[:body]        ||= "Important stuff!"
    mail = Mail.new do
      from    opts[:from]
      to      to
      subject opts[:subject]
      body    opts[:body]
    end
    mail.deliver!
  end
  
  def solr_client
    @solr_client ||= RSolr.connect(Indexer.config.solr.to_hash)
  end

  # cache coll_hash so each item doesn't need to look up the collection title -- we only look it up once per harvest.
  # @return [Hash<String, String>] collection druids as keys, and the objectLabel from the collection's identityMetadata as the value
  def coll_hash
    @coll_hash ||= {}
  end

  # cache formats from each item so we have this info for indexing collection record 
  # @return [Hash<String, Array<String>>] collection druids as keys, array of item formats as values
  def self.format_hash
    @@format_hash ||= {}
  end

end