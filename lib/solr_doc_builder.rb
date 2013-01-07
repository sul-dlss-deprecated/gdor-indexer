require 'logger'

require 'harvestdor'
require 'stanford-mods'
require 'mods_fields'
require 'public_xml_fields'

# Class to build the Hash representing a Solr document for a particular druid
class SolrDocBuilder

  # The druid of the item
  attr_reader :druid
  # Stanford::Mods::Record 
  attr_reader :smods_rec
  # Nokogiri::XML::Document The public xml, containing contentMetadata, identityMetadata, etc.
  attr_reader :public_xml
  attr_reader :logger

  # @param [String] druid, e.g. ab123cd4567
  # @param [Stanford::Mods::Record] the object associated with this druid
  # @param [Nokogiri::XML::Document] the public xml from the purl page for this druid, as a Nokogiri document
  def initialize(druid, harvestdor_client, logger)
    @druid = druid
    @harvestdor_client = harvestdor_client
    @logger = logger
    @smods_rec = smods_rec
    @public_xml = public_xml
  end
  
  # Create a Hash representing the Solr doc to be written to Solr, based on MODS and public_xml
  # @return [Hash] Hash representing the Solr document
  def doc_hash
    doc_hash = {
      :id => @druid, 
      :druid => @druid, 
      :modsxml => "#{@smods_rec.to_xml}",
    }
    
    doc_hash[:access_facet] = 'Online'
    # from public_xml_fields
    doc_hash[:display_type] = display_type  # defined in public_xml_fields
    doc_hash[:img_info] = image_ids unless !image_ids
    doc_hash[:format] = format

    doc_hash.merge!(doc_hash_from_mods) if doc_hash_from_mods
    
    # TODO:  verify:  all searchworks fields per sw_index.properties and  schema.xml

    doc_hash
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
  
  # If MODS record has a top level typeOfResource element with value 'still image'
  #  (<mods><typeOfResource>still image<typeOfResource>) then return true; false otherwise
  # @return true if MODS indicates this is an image object
  def image?
    @smods_rec.typeOfResource.each { |n|  
      return true if n.text == 'still image'
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
      :topic_search => topic_search, 
      :geographic_search => geographic_search,
      :subject_other_search => subject_other_search, 
      :subject_other_subvy_search => subject_other_subvy_search,
      :subject_all_search => subject_all_search, 
      :topic_facet => topic_facet,
      :geographic_facet => geographic_facet,
      :era_facet => era_facet,

      :language => @smods_rec.sw_language_facet,
      
      # remaining: go through all MODS elements (per MODS spec, not wiki doc)
      
    }
    # hash entries only added if there are values
    vals =  @smods_rec.term_values(:accessCondition)
    doc_hash[:access_condition_display] = vals if vals
    vals =  @smods_rec.term_values(:abstract)
    doc_hash[:summary_search] = vals if vals
    doc_hash[:collection_type] = 'Digital Collection' if collection?
    
    # all_search
    
    doc_hash
  end
  
  
  # return the mods for the druid as a Stanford::Mods::Record object
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