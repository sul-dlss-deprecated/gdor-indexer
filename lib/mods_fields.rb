# A mixin to the SolrDocBuilder class.
# Methods for Solr field values determined from MODS that aren't absolutely trivial mods or stanford-mods method calls 
class SolrDocBuilder

  # Values are the contents of:
  #   mods/genre
  #   mods/subject/topic
  # @return [Array<String>] values for the topic_search Solr field for this document or nil if none
  def topic_search
    vals = mods_values(:genre) || []
    # FIXME:  want convenience method for multi-level nodes???
    @smods_rec.subject.topic.each { |n| 
      vals << n.text unless n.text.empty? 
    }
    return nil if vals.empty?
    vals
  end

  # Values are the contents of:
  #   subject/temporal
  #   subject/genre
  # @return [Array<String>] values for the topic_search Solr field for this document or nil if none
  def subject_other_subvy_search
    vals = []
    # FIXME:  want convenience method for multi-level nodes???
    @smods_rec.subject.temporal.each { |n| 
      vals << n.text unless n.text.empty? 
      @logger.info("#{@druid} has subject temporal element with untranslated encoding: #{n.to_xml}") unless n.encoding.empty?
    }
    @smods_rec.subject.genre.each { |n| 
      vals << n.text unless n.text.empty? 
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
  
  
  protected #----------------------------------------------------------
  
  # @param [Symbol] message_sym the symbol of the message to send to the Stanford::Mods::Record object; 
  #  usually a term from the nom-xml terminology defined in the mods gem.
  # @param [String] sep - the separator string to insert between multiple values
  # @return [String] a String representing the value.  If there are multiple values, they will be concatenated with the separator 
  def mods_value message_sym, sep = ' '
    nodes = @smods_rec.send(message_sym)
    val = ''
    if nodes
      nodes.each { |n| 
        val << sep + n.text unless n.text.empty?
      }
    end
    return nil if val.strip.empty?
    val.strip
  rescue NoMethodError
    @logger.error("#{@druid} tried to get mods_value for unknown message: #{message_sym}")
    nil
  end
  
  # @param [Symbol] message_sym the symbol of the message to send to the Stanford::Mods::Record object; 
  #  usually a term from the nom-xml terminology defined in the mods gem.
  # @return [Array<String>] an Array with a String value for each node's text 
  def mods_values message_sym
    nodes = @smods_rec.send(message_sym)
    vals = []
    if nodes
      nodes.each { |n| 
        vals << n.text unless n.text.empty?
      }
    end
    return nil if vals.empty?
    vals
  rescue NoMethodError
    @logger.error("#{@druid} tried to get mods_values for unknown message: #{message_sym}")
    nil
  end

end