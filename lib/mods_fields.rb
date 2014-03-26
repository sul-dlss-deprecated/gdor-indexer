# A mixin to the SolrDocBuilder class.
# Methods for Solr field values determined from MODS that aren't absolutely trivial mods or stanford-mods method calls 
class SolrDocBuilder 
  
  # add_display_type is a way of adding distinguishing display_type values to searchworks 
  # so that we can use to distinguish different display needs for specific collections
  # e.g., Hydrus objects are a special display case
  # Based on a value of :add_display_type in a collection's config file
  # @return String the string to add to the front of the display_type value
  def add_display_type
    Indexer.config[:add_display_type]
  end

  def date_type_sym
    vals = @smods_rec.term_values([:origin_info,:dateIssued])
    if vals and vals.length > 0
      return :publication_year_isi
    end
    vals = @smods_rec.term_values([:origin_info,:dateCreated])  
    if vals and vals.length > 0
      return :creation_year_isi
    end
    nil
  end
   
  # select one or more format values from the controlled vocabulary here:
  #   http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=format&rows=0&facet.sort=index
  # based on the dor_content_type
  # @return [String] value in the SearchWorks controlled vocabulary
  def format
    val = @smods_rec.format ? @smods_rec.format : []
    
    if Indexer.config[:add_format]
      val << Indexer.config[:add_format]
    end
    if collection_formats and collection_formats.length > 0
      return collection_formats.concat(val).uniq
    end
    if val.length > 0
      return val.uniq
    end
    if not @smods_rec.typeOfResource or @smods_rec.typeOfResource.length == 0
      @logger.warn "#{@druid} has no valid typeOfResource"
      []
    end
  end
  
  # get the formats for this solr_doc_builder's druid stored during the indexing process
  #  note that the only formats stored are for collection druids
  def collection_formats
    vals = Indexer.format_hash[@druid]
    vals ? vals.uniq : nil
  end

  def pub_date
    val = @smods_rec.pub_year
    if val
      return val unless Indexer.config[:max_pub_date] && Indexer.config[:min_pub_date]
      return val if val.include? '-'
      if val and val.to_i < Indexer.config[:max_pub_date] and val.to_i > Indexer.config[:min_pub_date]
        return val
      end
    end
    if val 
      @logger.info("#{@druid} skipping date out of range "+val)
    end
    nil
  end

  # @return [String] value with the numeric catkey in it, or nil if none exists
  # sought in MODS top level:
  # <recordInfo>
  #	  <recordIdentifier source="SIRSI">a6780453</recordIdentifier>
  # </recordInfo>
  def catkey
    rec_id = @smods_rec.record_info.recordIdentifier
    if rec_id && !rec_id.empty? && rec_id.first.source == 'SIRSI'
      return rec_id.first.text.gsub('a','') # need to ensure catkey is numeric only
    end
    nil
  end
  
end