# A mixin to the GDor::Indexer::SolrDocBuilder class.
# Methods for Solr field values determined from the DOR object's purl page public xml 
module GDor::Indexer::PublicXmlFields
  
  # value is used to tell SearchWorks UI app of specific display needs for objects
  # a config file value for add_display_type can be used to prepend a string to 
  #  xxx_collection or xxx_object 
  # e.g., Hydrus objects are a special display case
  # Based on a value of :add_display_type in a collection's config yml file
  # 
  # information on DOR content types:
  #   https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
  # @return String the string to pre-pend to the display_type value  (e.g. )
  # @return [String] 'collection' or DOR content type
  def display_type
    case dor_content_type
      when 'book'
        'book'
      when 'image', 'manuscript', 'map'
        'image'
      else
        'file'
    end
  end
  
  # the @id attribute of resource/file elements that match the display_type, including extension
  # @return [Array<String>] filenames
  def file_ids
    @file_ids ||= begin
      ids = []
      if content_md
        if display_type == "image"
          content_md.xpath('./resource[@type="image"]/file/@id').each { |node|
            ids << node.text if !node.text.empty?
          }
        elsif display_type == "file"
          content_md.xpath('./resource/file/@id').each { |node|
            ids << node.text if !node.text.empty?
          }
        end
      end
      return nil if ids.empty?
      ids
    end
  end

  # @return true if the identityMetadata has <objectType>collection</objectType>, false otherwise
  def coll_object?
    @is_collection ||= begin
      if identity_md
        object_type_nodes = identity_md.xpath('./objectType')
        return true if object_type_nodes.find_index { |n| n.text == 'collection'}
      end
      false
    end
  end

  # get the druids from isMemberOfCollection relationships in rels-ext from public_xml
  # @return [Array<String>] the druids (e.g. ww123yy1234) this object has isMemberOfColletion relationship with, or nil if none
  def coll_druids_from_rels_ext
    @coll_druids_from_rels_ext ||= begin
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
  
  protected #---------------------------------------------------------------------
  
  # the value of the type attribute for a DOR object's contentMetadata
  #  more info about these values is here:
  #    https://consul.stanford.edu/display/chimera/DOR+content+types%2C+resource+types+and+interpretive+metadata
  #    https://consul.stanford.edu/display/chimera/Summary+of+Content+Types%2C+Resource+Types+and+their+behaviors
  # @return [String] 
  def dor_content_type
    @dor_content_type ||= begin
      dct = content_md ? content_md.xpath('@type').text : nil
      logger.error "#{druid} has no DOR content type (<contentMetadata> element may be missing type attribute)" if !dct || dct.empty?
      dct
    end
  end
  
  # the contentMetadata for this object, derived from the public_xml
  # @return [Nokogiri::XML::Element] containing the contentMetadata
  def content_md 
    @content_md ||= begin
      c_md = public_xml.root.xpath('/publicObject/contentMetadata').first
      logger.error("#{@druid} missing contentMetadata") if !c_md
      c_md
    end
  end
  
  # the identityMetadata for this object, derived from the public_xml 
  # @return [Nokogiri::XML::Element] containing the identityMetadata
  def identity_md
    @identity_md ||= begin
      id_md = public_xml.root.xpath('/publicObject/identityMetadata').first
      logger.error("#{@druid} missing identityMetadata") if !id_md
      id_md
    end
  end
  
end # GDor::Indexer::SolrDocBuilder class