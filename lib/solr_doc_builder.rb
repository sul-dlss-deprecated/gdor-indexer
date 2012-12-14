
# NAOMI_MUST_COMMENT_THIS
class SolrDocBuilder

  # The druid of the item
  attr_reader :druid
  # Stanford::Mods::Record 
  attr_accessor :mods
  # Nokogiri::XML::Document The content metadata xml, used for knowing what kind of object this is
  attr_accessor :content_metadata

  # @param [String] druid, e.g. ab123cd4567
  def initialize(druid, mods)
    @druid = druid
    @mods = mods
  end

  # Create a Solr doc, as a Hash, to be added to the SearchWorks Solr index.
  # Solr doc contents are based on the mods, contentMetadata, etc. for the druid
  # @return [Hash] Hash representing the Solr document
  def to_doc_hash
    doc_hash = { 
      :id => druid, 
      :druid => druid, 
      :access_facet => 'Online',
# yet another thing to pass in.  Hmmmm.      
#      :url_fulltext => "#{config.purl}/#{druid}",
      :modsxml => "#{@mods.to_xml}"
    }
    doc_hash
  end

end # SolrDocBuilder class
