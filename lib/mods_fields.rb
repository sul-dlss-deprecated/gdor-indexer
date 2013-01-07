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

  # Values are the contents of:
  #   subject/name
  #   subject/occupation  - no subelements
  #   subject/titleInfo
  # @return [Array<String>] values for the subject_other_search Solr field for this document or nil if none
  def subject_other_search
    vals = @smods_rec.term_values([:subject, :occupation]) || []
    nvals = @smods_rec.sw_subject_names
    vals.concat(nvals) if nvals
    tvals = @smods_rec.sw_subject_titles
    vals.concat(tvals) if tvals

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
  
  # Values are the contents of:
  #  all subject subelements except subject/cartographic plus  genre top level element
  # @return [Array<String>] values for the subject_all_search Solr field for this document or nil if none
  def subject_all_search
    vals = topic_search || []
    vals.concat(geographic_search) if geographic_search
    vals.concat(subject_other_search) if subject_other_search
    vals.concat(subject_other_subvy_search) if subject_other_subvy_search
    return nil if vals.empty?
    vals
  end
  
  # subject facet fields
  # remove trailing punct  [\\\\,;] --> in stanford-mods gem (?)
#  :topic_facet => 'foo',  # subject/name, subject/occupation, subject/titleInfo, subject/topic
#  :geographic_facet => 'foo', # subject/geographic, subject/hierarchicalGeographic,  (also translate subject/geographicCode ...)
#  :era_facet => 'foo', # subject/temporal
  

end