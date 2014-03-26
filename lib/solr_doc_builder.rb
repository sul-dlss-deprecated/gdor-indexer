require 'logger'

require 'harvestdor'
require 'stanford-mods'
require 'gdor_mods_fields'
include GdorModsFields
require 'public_xml_fields'
include PublicXmlFields


# Class to build the Hash representing a Solr document for a particular druid
class SolrDocBuilder

  # The druid of the item
  attr_reader :druid
  # Stanford::Mods::Record 
  attr_reader :smods_rec
  # Nokogiri::XML::Document The public xml, containing contentMetadata, identityMetadata, etc.
  attr_reader :public_xml
  attr_reader :logger

  # @param [String] druid e.g. ab123cd4567
  # @param [Harvestdor::Client] harvestdor_client used to get MODS and public_xml
  # @param [Logger] logger for indexing messages
  def initialize(druid, harvestdor_client, logger)
    @druid = druid
    @harvestdor_client = harvestdor_client
    @logger = logger
    @smods_rec = smods_rec
    @smods_rec.druid=druid
    @public_xml = public_xml
  end
  
  # Create a Hash representing the Solr doc to be written to Solr, based on MODS and public_xml
  # @return [Hash] Hash representing the Solr document
  def doc_hash
    if not @doc_hash
      doc_hash = {
        :id => @druid, 
        :druid => @druid, 
        :modsxml => "#{@smods_rec.to_xml}",
      }
    
      doc_hash[:access_facet] = 'Online'
      # from public_xml_fields
      doc_hash[:display_type] = display_type  # defined in public_xml_fields
      doc_hash[:img_info] = image_ids unless !image_ids
      doc_hash[:format] = format # defined in mods_fields
      hash_from_mods = doc_hash_from_mods
      doc_hash.merge!(hash_from_mods) if hash_from_mods 
      @doc_hash = doc_hash
    end
    @doc_hash
  end
  
  # If MODS record has a top level typeOfResource element with attribute collection set to 'yes,
  #  (<mods><typeOfResource collection='yes'>) then return true; false otherwise
  # @return true if MODS indicates this is a collection object
  def collection?
    @smods_rec.typeOfResource.each { |n|  
      return true if n.collection == 'yes'
    }
    false
  end

  # Create a Hash representing a Solr doc, with all MODS related fields populated.
  # @return [Hash] Hash representing the Solr document
  def doc_hash_from_mods
    doc_hash = { 
      # title fields
      :title_245a_search => @smods_rec.sw_short_title,
      :title_245_search => @smods_rec.sw_full_title,
      :title_variant_search => @smods_rec.sw_addl_titles,
      :title_sort => @smods_rec.sw_sort_title,
      :title_245a_display => @smods_rec.sw_short_title,
      :title_display => @smods_rec.sw_full_title,
      :title_full_display => @smods_rec.sw_full_title,
      
      # author fields
      :author_1xx_search => @smods_rec.sw_main_author,
      :author_7xx_search => @smods_rec.sw_addl_authors,
      :author_person_facet => @smods_rec.sw_person_authors,
      :author_other_facet => @smods_rec.sw_impersonal_authors,
      :author_sort => @smods_rec.sw_sort_author,
      :author_corp_display => @smods_rec.sw_corporate_authors,
      :author_meeting_display => @smods_rec.sw_meeting_authors,
      :author_person_display => @smods_rec.sw_person_authors,
      :author_person_full_display => @smods_rec.sw_person_authors,
      
      # subject search fields
      :topic_search => @smods_rec.topic_search, 
      :geographic_search => @smods_rec.geographic_search,
      :subject_other_search => @smods_rec.subject_other_search, 
      :subject_other_subvy_search => @smods_rec.subject_other_subvy_search,
      :subject_all_search => @smods_rec.subject_all_search, 
      :topic_facet => @smods_rec.topic_facet,
      :geographic_facet => @smods_rec.geographic_facet,
      :era_facet => @smods_rec.era_facet,

      :language => @smods_rec.sw_language_facet,
      :physical =>  @smods_rec.term_values([:physical_description, :extent]),
      :summary_search => @smods_rec.term_values(:abstract),
      :toc_search => @smods_rec.term_values(:tableOfContents),
      :url_suppl => @smods_rec.term_values([:related_item, :location, :url]),

      # publication fields
      :pub_search =>  @smods_rec.place,
      :pub_date_sort =>  @smods_rec.pub_date_sort,
      :pub_date_group_facet =>  @smods_rec.pub_date_groups(pub_date), 
      :pub_date =>  @smods_rec.pub_date_facet,
      :imprint_display =>  @smods_rec.pub_date_display,
      :pub_date_display =>  @smods_rec.pub_date_display,
      
      :all_search => @smods_rec.text  
    }
    
    # more pub date fields
    pub_date_sort = @smods_rec.pub_date_sort
    if is_positive_int? pub_date_sort
       doc_hash[:pub_year_tisim] =  pub_date_sort
      # put the displayable year in the correct field, :creation_year_isi for example
      doc_hash[date_type_sym] =  @smods_rec.pub_date_sort  if date_type_sym
    end
    
    # FIXME:  move this line out to indexer.index_collection_druid method?
    doc_hash[:collection_type] = 'Digital Collection' if collection?
    doc_hash
  end
  
  # @return array of Strings pertaining to absence of required fields
  def validate
    messages = []
    messages << "#{@druid} missing druid" if doc_hash.blank? :druid
    messages << "#{@druid} missing modsxml" if doc_hash.blank? :modsxml
    messages << "#{@druid} missing access_facet" if doc_hash.blank? :access_facet
    messages << "#{@druid} missing display_type" if display_type.kind_of?(String) && doc_hash.blank?(:display_type)
    messages << "#{@druid} missing format" if doc_hash.blank? :format
    messages << "#{@druid} missing title" if doc_hash.blank? :title_display
    messages << "#{@druid} missing pub year for date slider" if doc_hash.blank? :pub_year_tisim
    messages << "#{@druid} missing author" if doc_hash.blank? :author_person_display
    messages << "#{@druid} missing language" if doc_hash.blank? :language
    messages
  end

  # @return true if the string parses into an int, and if so, the int is >= 0
  def is_positive_int? str
    begin
      if str.to_i >= 0
        return true
      else
        return false
      end
    rescue
    end
    return false
  end

  # determines particular flavor of displayable publication year field 
  # @return Solr field name as a symbol
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
  
  # @return [String] value with the numeric catkey in it, or nil if none exists
  # sought in MODS top level:
  # 
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

  # return the MODS for the druid as a Stanford::Mods::Record object
  # @return [Stanford::Mods::Record] created from the MODS xml for the druid
  def smods_rec
    if @mods_rec.nil?
      ng_doc = @harvestdor_client.mods @druid
      raise "Empty MODS metadata for #{druid}: #{ng_doc.to_xml}" if ng_doc.root.xpath('//text()').empty?
      @mods_rec = Stanford::Mods::Record.new
      @mods_rec.from_nk_node(ng_doc.root)
    end
    @mods_rec
  end
  
  # the public_xml for the druid as a Nokogiri::XML::Document object
  # @return [Nokogiri::XML::Document] containing the public xml for the druid
  def public_xml 
    @public_xml ||= @harvestdor_client.public_xml @druid
  end
  
end # SolrDocBuilder class

class Hash
  def blank? field
    self[field].nil? || self[field].length == 0
  end
end

