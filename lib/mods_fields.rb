# A mixin to the SolrDocBuilder class.
# Methods for Solr field values determined from MODS that aren't absolutely trivial mods or stanford-mods method calls 
class SolrDocBuilder

  # Values are the contents of:
  #   mods/genre
  #   mods/subject/topic
  # @return [Array<String>] values for the topic_search Solr field for this document or nil if none
  def topic_search
    vals = @smods_rec.term_values(:genre) || []
    tvals = @smods_rec.term_values([:subject, :topic])
    vals.concat(tvals) if tvals

    return nil if vals.empty?
    vals
  end

  # Values are the contents of:
  #   subject/geographic
  #   subject/hierarchicalGeographic
  #   subject/geographicCode  (only include the translated value if it isn't already present from other mods geo fields)
  # @return [Array<String>] values for the geographic_search Solr field for this document or nil if none
  def geographic_search
    vals = @smods_rec.term_values([:subject, :geographic]) || []
    gvals = @smods_rec.term_values([:subject, :hierarchicalGeographic])
    vals.concat(gvals) if gvals
    cvals = @smods_rec.subject.geographicCode.translated_value
    if cvals
      cvals.each { |val|  
        vals << val if !vals.include?(val)
      }
    end

    # print a message for any unrecognized encodings
    codes = @smods_rec.term_values([:subject, :geographicCode]) 
    if codes && codes.size > cvals.size
      @smods_rec.subject.geographicCode.each { |n|
        if n.authority != 'marcgac' && n.authority != 'marccountry'
          @logger.info("#{@druid} has subject geographicCode element with untranslated encoding (#{n.authority}): #{n.to_xml}")
        end
      }
    end

    return nil if vals.empty?
    vals    
  end

  # Values are the contents of:
  #   subject/temporal
  #   subject/genre
  # @return [Array<String>] values for the subject_other_subvy_search Solr field for this document or nil if none
  def subject_other_subvy_search
    vals = @smods_rec.term_values([:subject, :temporal]) || []
    gvals = @smods_rec.term_values([:subject, :genre])
    vals.concat(gvals) if gvals

    # print a message for any temporal encodings
    @smods_rec.subject.temporal.each { |n| 
      @logger.info("#{@druid} has subject temporal element with untranslated encoding: #{n.to_xml}") if !n.encoding.empty?
    }
    
    return nil if vals.empty?
    vals
  end
  
  # subject search fields

#  :geographic_search => 'foo', # subject/geographic, subject/hierarchicalGeographic,  (also translate subject/geographicCode ...)
#  :subject_other_search => 'foo', # subject/name, subject/occupation, subject/titleInfo 
#  :subject_all_search => 'foo', # all of the above 
  # subject facet fields
  # remove trailing punct  [\\\\,;] --> in stanford-mods gem (?)
#  :topic_facet => 'foo',  # subject/name, subject/occupation, subject/titleInfo, subject/topic
#  :geographic_facet => 'foo', # subject/geographic, subject/hierarchicalGeographic,  (also translate subject/geographicCode ...)
#  :era_facet => 'foo', # subject/temporal
  

end