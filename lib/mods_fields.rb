# A mixin to the SolrDocBuilder class.
# Methods for Solr field values determined from MODS that aren't absolutely trivial mods or stanford-mods method calls 
class SolrDocBuilder

  # Values are the contents of:
  #   mods/genre
  #   mods/subject/topic
  # @return [Array<String>] values for the topic_search Solr field for this document or nil if none
  def topic_search
    @topic_search ||= begin
      vals = @smods_rec.term_values(:genre) || []
      vals.concat(subject_topics) if subject_topics
      vals.empty? ? nil : vals
    end
  end

  def main_author_w_date_test
    result = nil
    first_wo_role = nil
    @smods_rec.plain_name.each { |n|
      if n.role.size == 0
        first_wo_role ||= n
      end
      n.role.each { |r|
        if r.authority.include?('marcrelator') && 
          (r.value.include?('Creator') || r.value.include?('Author'))
          result ||= n.display_value_w_date
        end          
      }
    }
    if !result && first_wo_role
      result = first_wo_role.display_value_w_date
    end
    result
  end
  #remove trailing commas
  def sw_full_title
    toret = @smods_rec.sw_full_title
    if toret
      toret = toret.gsub(/,$/, '')
    end
    toret
  end


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
  # @return [Array<String>] values for the pub_date_group_facet
  def pub_date_groups year
    if not year
      return nil
    end
    year=year.to_i
    current_year=Time.new.year.to_i
    result = []
    if year >= current_year - 1
      result << "This year"
    else
      if year >= current_year - 3
        result << "Last 3 years"
      else
        if year >= current_year - 10
          result << "Last 10 years"
        else
          if year >= current_year - 50
            result << "Last 50 years"
          else
            result << "More than 50 years ago"
          end
        end
      end
    end
  end

  # select one or more format values from the controlled vocabulary here:
  #   http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=format&rows=0&facet.sort=index
  # based on the dor_content_type
  # @return [String] value in the SearchWorks controlled vocabulary
  def format
    val=[]
    formats=@smods_rec.term_values(:typeOfResource)
    if formats
      formats.each do |form|
        case form
        when 'still image'
          val << 'Image'
        when 'mixed material'
          val << 'Manuscript/Archive'
        when 'moving image'
          val << 'Video'
        when 'three dimensional object'
          val <<'Other'
        when 'cartographic'
          val << 'Map/Globe'
        when 'sound recording-musical'
          val << 'Music-Recording'
        when 'sound recording-nonmusical'
          val << 'Sound Recording'
        when 'software, multimedia'
          val << 'Computer File'      
        else
          @logger.warn "#{@druid} has an unknown typeOfResource #{form}"
        end
      end
    end
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
  #get the dates from dateIssued, and dateCreated merged into 1 array.
  # @return [Array<String>] values for the issue_date_display Solr field for this document or nil if none
  def pub_dates
    vals = @smods_rec.term_values([:origin_info,:dateIssued])
    if vals
      vals = vals.concat @smods_rec.term_values([:origin_info,:dateCreated]) unless not @smods_rec.term_values([:origin_info,:dateCreated])
    else
      vals = @smods_rec.term_values([:origin_info,:dateCreated])
    end
    vals and vals.empty? ? nil : vals
  end
  def is_number?(object)
    true if Integer(object) rescue false
  end
  def is_date?(object)
    true if Date.parse(object) rescue false
  end
  # Get the publish year from mods
  #@return [String] 4 character year or nil if no valid date was found
  def pub_year
    #use the cached year if there is one
    if @pub_year
      if @pub_year == ''
        return nil
      end
      return @pub_year
    end
    dates=pub_dates
    if dates
      dates.each do |f_date|
        #remove ? and [] 
        f_date=f_date.gsub('?','').gsub('[','').gsub(']','')
        # just regex for 4 numbers
        matches=f_date.scan(/\d{4}/)
        #if there is only 1 candidate, use it
        if matches.length == 1
          @pub_year=matches.first 
          return matches.first
        else
          #if there are multiples, check for ones with CE after them
          matches.each do |match|
            #look for things like '1865-6 CE'
            pos = f_date.index(Regexp.new(match+'...CE'))
            pos = pos ? pos.to_i : 0
            if f_date.include?(match+' CE') or pos > 0
              @pub_year=match
              return match
            end 
          end
          if matches.length>0
            @pub_year=matches.first 
            return matches.first
          end
          #look for a century listing like '13th century'
          matches=f_date.scan(/\d{2}th/)
          if matches.length == 1
            @pub_year=((matches.first[0,2].to_i)-1).to_s+'--'
            return @pub_year
          end
          #if there are multiples, check for ones with CE after them
          if matches.length > 0
            matches.each do |match|
              pos = f_date.index(Regexp.new(match+'...CE'))
              pos = pos ? pos.to_i : 0
              if f_date.include?(match+' CE') or pos > 0
                @pub_year=((match[0,2].to_i) - 1).to_s+'--'
                return @pub_year
              end 
            end
          end
        end
      end
    end
    @pub_year=''
    @logger.info("#{@druid} no valid pub date found in '#{dates.to_s}'")
    return nil
  end
  #The year the object was published, , filtered based on max_pub_date and min_pub_date from the config file
  #@return [String] 4 character year or nil
  def pub_date
    val=pub_year
    #@logger.info("#{druid} using date #{val} from #{pub_dates.inspect}")
    return val unless Indexer.config[:max_pub_date] && Indexer.config[:min_pub_date]
    return val if val.include? '-'
    if val and val.to_i < Indexer.config[:max_pub_date] and val.to_i > Indexer.config[:min_pub_date]
      return val
    end
    if val 
      @logger.info("#{@druid} skipping date out of range "+val)
    end
    nil
  end
  #Values for the pub date facet. This is less strict than the 4 year date requirements for pub_date
  #@return <Array[String]> with values for the pub date facet
  def pub_date_facet
    if pub_date
      if pub_date.include? '--'
        cent=pub_date[0,2].to_i
        cent+=1
        cent=cent.to_s+'th century'
        cent
      else
        pub_date
      end
    else
      nil
    end
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