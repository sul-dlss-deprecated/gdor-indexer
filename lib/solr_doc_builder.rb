require 'logger'

require 'harvestdor'
require 'stanford-mods'
require 'hash_mixin'
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
    @smods_rec.druid = druid
    @public_xml = public_xml
  end
  
  # Create a Hash representing the Solr doc to be written to Solr, based on MODS and public_xml
  # @return [Hash] Hash representing the Solr document
  def doc_hash
    if not @doc_hash
      @doc_hash = {
        :id => @druid, 
        :modsxml => "#{@smods_rec.to_xml}",
      }
      hash_from_mods = doc_hash_from_mods # defined in gdor_mods_fields
      @doc_hash.merge!(hash_from_mods) if hash_from_mods
    end
    @doc_hash
  end
  
  # validate fields that should be in doc hash for every unmerged gryphonDOR object in SearchWorks Solr
  # @return [Array<String>] array of Strings indicating absence of required fields
  def validate_mods druid = @druid, doc_fields_hash = doc_hash
    result = []
    result << "#{druid} missing modsxml\n" if !doc_fields_hash.field_present?(:modsxml)
    result << "#{druid} missing resource type\n" if !doc_fields_hash.field_present?(:format_main_ssim)
    result << "#{druid} missing format\n" if !doc_fields_hash.field_present?(:format) # for backwards compatibility
    result << "#{druid} missing title\n" if !doc_fields_hash.field_present?(:title_display)
    result << "#{druid} missing pub year for date slider\n" if !doc_hash.field_present?(:pub_year_tisim)
    result << "#{druid} missing author\n" if !doc_fields_hash.field_present?(:author_person_display)
    result << "#{druid} missing language\n" if !doc_fields_hash.field_present?(:language)
    result
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
          rec_id = @smods_rec.record_info.recordIdentifier
          if rec_id && !rec_id.empty? && rec_id.first.source == 'SIRSI'
            catkey = rec_id.first.text.gsub('a','') # need to ensure catkey is numeric only
          else
            @logger.error("#{druid} has barcode #{node.first.content} in identityMetadata but no SIRSI catkey in mods")
          end
        end
      end
      catkey
    end
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
