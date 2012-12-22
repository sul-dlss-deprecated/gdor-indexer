require 'stanford-mods'
 
# A mixin to the SolrDocBuilder class.
# Methods for SearchWorks Solr field values
class SolrDocBuilder

  # select one or more format values from the controlled vocabulary here:
  #   http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=format&rows=0&facet.sort=index
  # based on the dor_content_type  and/or what's in the Mods
  # @return [String] value in the SearchWorks controlled vocabulary
  def format
    if dor_content_type == 'image'
      'Image'
    end
  end

  protected #---------------------------------------------------------------------
  
  # the value of the type attribute for a DOR object's contentMetadata
  #  more info about these values is here:
  #    https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
  #    https://consul.stanford.edu/display/chimera/Summary+of+Content+Types%2C+Resource+Types+and+their+behaviors
  # @return [String] 
  def dor_content_type
    content_md.xpath('@type').text
  end
  
  # the contentMetadata for this object, derived from the public_xml
  # @return [Nokogiri::XML::Element] containing the contentMetadata
  def content_md 
    @content_md ||= public_xml.root.xpath('/publicObject/contentMetadata').first
  end
  
  
end