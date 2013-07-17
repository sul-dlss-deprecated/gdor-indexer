# A mixin to the SolrDocBuilder class.
# Methods for Solr field values determined from MODS that aren't absolutely trivial mods or stanford-mods method calls 
class SolrDocBuilder


  # Values are the contents of:
  #   subject/geographic
  #   subject/hierarchicalGeographic
  #   subject/geographicCode  (only include the translated value if it isn't already present from other mods geo fields)
  # @return [Array<String>] values for the geographic_search Solr field for this document or nil if none
  def geographic_search
    @geographic_search ||= begin
      result = @smods_rec.sw_geographic_search

      # TODO:  this should go into stanford-mods ... but then we have to set that gem up with a Logger
      # print a message for any unrecognized encodings
      xvals = @smods_rec.subject.geographicCode.translated_value
      codes = @smods_rec.term_values([:subject, :geographicCode]) 
      if codes && codes.size > xvals.size
        @smods_rec.subject.geographicCode.each { |n|
          if n.authority != 'marcgac' && n.authority != 'marccountry'
            @logger.info("#{@druid} has subject geographicCode element with untranslated encoding (#{n.authority}): #{n.to_xml}")
          end
        }
      end

      # FIXME:  stanford-mods should be returning [], not nil ... 
      return nil if !result || result.empty?
      result
    end
  end

  # Values are the contents of:
  #   subject/name
  #   subject/occupation  - no subelements
  #   subject/titleInfo
  # @return [Array<String>] values for the subject_other_search Solr field for this document or nil if none
  def subject_other_search
    @subject_other_search ||= begin
      vals = subject_occupations ? Array.new(subject_occupations) : []
      vals.concat(subject_names) if subject_names
      vals.concat(subject_titles) if subject_titles
      vals.empty? ? nil : vals
    end
  end

  # Values are the contents of:
  #   subject/temporal
  #   subject/genre
  # @return [Array<String>] values for the subject_other_subvy_search Solr field for this document or nil if none
  def subject_other_subvy_search
    @subject_other_subvy_search ||= begin
      vals = subject_temporal ? Array.new(subject_temporal) : []
      gvals = @smods_rec.term_values([:subject, :genre])
      vals.concat(gvals) if gvals

      # print a message for any temporal encodings
      @smods_rec.subject.temporal.each { |n| 
        @logger.info("#{@druid} has subject temporal element with untranslated encoding: #{n.to_xml}") if !n.encoding.empty?
      }

      vals.empty? ? nil : vals
    end
  end
 
  
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
      return :production_year_isi
    end
    nil
  end
   
  # select one or more format values from the controlled vocabulary here:
  #   http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=format&rows=0&facet.sort=index
  # based on the dor_content_type
  # @return [String] value in the SearchWorks controlled vocabulary
  def format
    val=@smods_rec.format ? @smods_rec.format : []
    
    if Indexer.config[:add_format]
      val << Indexer.config[:add_format]
    end
    if collection_formats and collection_formats.length>0
      return collection_formats.concat(val).uniq
    end
    if val.length>0
      return val.uniq
    end
    if not @smods_rec.typeOfResource or @smods_rec.typeOfResource.length == 0
      @logger.warn "#{@druid} has no valid typeOfResource"
      []
    end
  end
  #get the languages stored during the indexing process for this collection
  def collection_language
    if Indexer.language_hash[@druid]
      toret=[]
      Indexer.language_hash[@druid].each do |k,v|
        toret<<k
      end
      toret=toret.uniq
      toret
    end
  end
  
  #get the formats stored during the indexing process for this collection
  def collection_formats
    if Indexer.format_hash[@druid]
      toret=[]
      Indexer.format_hash[@druid].each do |k,v|
        toret<<k
      end
      toret=toret.uniq
      toret
    end
  end

  # Values are the contents of:
  #  all subject subelements except subject/cartographic plus  genre top level element
  # @return [Array<String>] values for the subject_all_search Solr field for this document or nil if none
  def subject_all_search
    vals = topic_search ? Array.new(topic_search) : []
    vals.concat(geographic_search) if geographic_search
    vals.concat(subject_other_search) if subject_other_search
    vals.concat(subject_other_subvy_search) if subject_other_subvy_search
    vals.empty? ? nil : vals
  end

  # Values are the contents of:
  #   subject/topic
  #   subject/name
  #   subject/title
  #   subject/occupation
  #  with trailing comma, semicolon, and backslash (and any preceding spaces) removed
  # @return [Array<String>] values for the topic_facet Solr field for this document or nil if none 
  def topic_facet
    vals = subject_topics ? Array.new(subject_topics) : []
    vals.concat(subject_names) if subject_names
    vals.concat(subject_titles) if subject_titles
    vals.concat(subject_occupations) if subject_occupations
    vals.map! { |val| 
      v = val.sub(/[\\,;]$/, '')
      v.strip
    }
    vals.empty? ? nil : vals
  end
    def pub_date
      val=@smods_rec.pub_year
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

  # geographic_search values with trailing comma, semicolon, and backslash (and any preceding spaces) removed
  # @return [Array<String>] values for the geographic_facet Solr field for this document or nil if none 
  def geographic_facet
    geographic_search.map { |val| val.sub(/[\\,;]$/, '').strip } unless !geographic_search
  end

  # subject/temporal values with trailing comma, semicolon, and backslash (and any preceding spaces) removed
  # @return [Array<String>] values for the era_facet Solr field for this document or nil if none 
  def era_facet
    subject_temporal.map { |val| val.sub(/[\\,;]$/, '').strip } unless !subject_temporal
  end
  # @return [String] value with the numeric catkey in it, or nil if none exists
  def catkey
    catkey=@smods_rec.term_values([:record_info,:recordIdentifier])
    if catkey and catkey.length>0
      return catkey.first.gsub('a','') #need to ensure catkey is numeric only
    end
    nil
  end

  # protected ----------------------------------------------------------

  # convenience method for subject/name/namePart values (to avoid parsing the mods for the same thing multiple times)
  def subject_names
    @subject_names ||= @smods_rec.sw_subject_names
  end

  # convenience method for subject/occupation values (to avoid parsing the mods for the same thing multiple times)
  def subject_occupations
    @subject_occupations ||= @smods_rec.term_values([:subject, :occupation])
  end

  # convenience method for subject/temporal values (to avoid parsing the mods for the same thing multiple times)
  def subject_temporal
    @subject_temporal ||= @smods_rec.term_values([:subject, :temporal])
  end

  # convenience method for subject/titleInfo values (to avoid parsing the mods for the same thing multiple times)
  def subject_titles
    @subject_titles ||= @smods_rec.sw_subject_titles
  end

  # convenience method for subject/topic values (to avoid parsing the mods for the same thing multiple times)
  def subject_topics
    @subject_topics ||= @smods_rec.term_values([:subject, :topic])
  end
end