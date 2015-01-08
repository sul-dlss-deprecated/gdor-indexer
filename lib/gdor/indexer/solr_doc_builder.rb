require 'logger'

require 'harvestdor'
require 'stanford-mods'
require 'gdor/indexer/solr_doc_hash'
require 'gdor/indexer/mods_fields'
require 'gdor/indexer/public_xml_fields'

# Class to build the Hash representing a Solr document for a particular druid
class GDor::Indexer::SolrDocBuilder
  include GDor::Indexer::ModsFields
  include GDor::Indexer::PublicXmlFields

  # The druid of the item
  attr_reader :resource
  attr_reader :logger

  # @param [Harvestdor::Indexer::Resource] resource used to get MODS and public_xml
  # @param [Logger] logger for indexing messages
  def initialize(resource, logger)
    @resource = resource
    @logger = logger
  end

  def druid
    resource.druid
  end

  # Create a Hash representing the Solr doc to be written to Solr, based on MODS and public_xml
  # @return [Hash] Hash representing the Solr document
  def doc_hash
    @doc_hash ||= begin
      doc_hash = GDor::Indexer::SolrDocHash.new id: resource.bare_druid, modsxml: smods_rec.to_xml
      hash_from_mods = doc_hash_from_mods # defined in gdor_mods_fields
      doc_hash.merge!(hash_from_mods) if hash_from_mods
      doc_hash
    end
  end

  # @return [String] value with SIRSI/Symphony numeric catkey in it, or nil if none exists
  # first we look for 
  #  identityMetadata/otherId[@name='catkey']
  # if not found, we look for 
  #  identityMetadata/otherId[@name='barcode']
  #   if found, we look for catkey in MODS
  #     mods/recordInfo/recordIdentifier[@source="SIRSI"
  #     and if found, remove the leading a
  # otherwise, nil
  def catkey
    @catkey ||= begin
      catkey = nil
      node = public_xml.xpath("/publicObject/identityMetadata/otherId[@name='catkey']") if public_xml
      catkey = node.first.content if node && node.first
      if !catkey
        # if there's a barcode in the identity metadata then look for a ckey in the MODS
        node = public_xml.xpath("/publicObject/identityMetadata/otherId[@name='barcode']")
        if node.first
          rec_id = smods_rec.record_info.recordIdentifier
          if rec_id && !rec_id.empty? && rec_id.first.source == 'SIRSI'
            catkey = rec_id.first.text.gsub('a','') # need to ensure catkey is numeric only
          else
            logger.error("#{druid} has barcode #{node.first.content} in identityMetadata but no SIRSI catkey in mods")
          end
        end
      end
      catkey
    end
  end

  # return the MODS for the druid as a Stanford::Mods::Record object
  # @return [Stanford::Mods::Record] created from the MODS xml for the druid
  def smods_rec
    @smods_rec ||= begin
      mods_rec = resource.smods_rec
      mods_rec.druid = druid # why?
      mods_rec
    end
  end
  
  # the public_xml for the druid as a Nokogiri::XML::Document object
  # @return [Nokogiri::XML::Document] containing the public xml for the druid
  def public_xml 
    resource.public_xml
  end
  
end # GDor::Indexer::SolrDocBuilder class
