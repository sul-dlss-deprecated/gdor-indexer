# A mixin to the SolrDocBuilder class.
# Methods for SearchWorks Solr field values
class SolrDocBuilder

  # select one or more format values from the controlled vocabulary here:
  #   http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=format&rows=0&facet.sort=index
  # based on the dor_content_type  and/or what's in the Mods
  # @return [String] value in the SearchWorks controlled vocabulary
  def format
    # information on DOR content types:
    #   https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
    if dor_content_type == 'image'
      'Image'
    else
      logger.warn "Object #{druid} has unrecognized DOR content type: #{dor_content_type}"
    end
  end
  
  #  TODO:  ask Jessie if this Solr field is still used by SearchWorks
  def display_type
    if collection?
      'collection'
    elsif dor_content_type
      dor_content_type
    else
      logger.warn "Object #{druid} has no DOR content type (possibly missing type attribute on <contentMetadata> element)"
    end
  end

# FIXME:  this should be a hash  coll druid => coll title!
  # @return [Array<String>] the druids (e.g. ww123yy1234) this object has isMemberOfColletion relationship with
  def collection_druids
# create nom-xml terminology for rels-ext in harvestdor?
    @collection_druids ||= begin
      ns_hash = {'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'fedora' => "info:fedora/fedora-system:def/relations-external#", '' => ''}
      is_member_of_nodes ||= public_xml.xpath('/publicObject/rdf:RDF/rdf:Description/fedora:isMemberOfCollection/@rdf:resource', ns_hash)
      # from public_xml rels-ext
      druids = []
      is_member_of_nodes.each { |n| 
        druids << n.value.split('druid:').last unless n.value.empty?
      }
      return nil if druids.empty?
      druids
    end
  end
  
  # NAOMI_MUST_COMMENT_THIS_METHOD
  def collection_titles
    # from collection object identity metadata ->  public_xml for collection druid or argo Solr?
    #collections[:names] << "#{id}-|-#{r["response"]["docs"][0]["obj_label_t"]}"
  end


  protected #---------------------------------------------------------------------
  
  # the value of the type attribute for a DOR object's contentMetadata
  #  more info about these values is here:
  #    https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
  #    https://consul.stanford.edu/display/chimera/Summary+of+Content+Types%2C+Resource+Types+and+their+behaviors
  # @return [String] 
  def dor_content_type
    @dor_content_type ||= content_md.xpath('@type').text
  end
  
  # the contentMetadata for this object, derived from the public_xml
  # @return [Nokogiri::XML::Element] containing the contentMetadata
  def content_md 
# FIXME:  create nom-xml terminology for contentMetadata in harvestdor?
    @content_md ||= public_xml.root.xpath('/publicObject/contentMetadata').first
  end
  
end # SolrDocBuilder class