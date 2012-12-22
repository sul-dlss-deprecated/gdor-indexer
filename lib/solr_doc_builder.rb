require 'stanford-mods'
require 'stanford-mods/searchworks'

# NAOMI_MUST_COMMENT_THIS
class SolrDocBuilder

  # The druid of the item
  attr_reader :druid
  # Stanford::Mods::Record 
  attr_reader :smods_rec
  # Nokogiri::XML::Document The public xml, containing contentMetadata, identityMetadata, etc.
  attr_reader :public_xml

  # @param [String] druid, e.g. ab123cd4567
  # @param [Stanford::Mods::Record] the object associated with this druid
  # @param [Nokogiri::XML::Document] the public xml from the purl page for this druid, as a Nokogiri document
  def initialize(druid, smods_rec, public_xml)
    @druid = druid
    @smods_rec = smods_rec
    @public_xml = public_xml
  end

  # Create a Hash representing a Solr doc, with all mods related fields populated.
  # @return [Hash] Hash representing the Solr document
  def mods_to_doc_hash
    doc_hash = { 
      :id => @druid, 
      :druid => @druid, 
# yet another thing to pass in.  Hmmmm.      
#      :url_fulltext => "#{config.purl}/#{druid}",
      :modsxml => "#{@smods_rec.to_xml}",

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

      # TO DO?  iterate over all methods in searchworks_fields mixins
    }
    doc_hash
  end
  
  # NAOMI_MUST_COMMENT_THIS_METHOD
  def addl_hash_fields
    doc_hash = {
      :access_facet => 'Online',      
    }
  end

end # SolrDocBuilder class
