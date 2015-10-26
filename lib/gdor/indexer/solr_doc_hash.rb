require 'delegate'

class GDor::Indexer
  class SolrDocHash < SimpleDelegator
    def initialize(hash = {})
      super(hash)
    end

    # looks for non-empty existence of field when exp_val is nil;
    # when exp_val is a String, looks for matching value as a String or as a member of an Array
    # when exp_val is a Regexp, looks for String value that matches, or Array with a String member that matches
    # @return true if the field is non-trivially present in the hash, false otherwise
    def field_present?(field, exp_val = nil)
      !!(if self.include?(field) && Array(self[field]).any? { |v| !v.blank? }
           actual = Array(self[field])

           case exp_val
           when nil
             true
           when Regexp
             actual.index { |s| exp_val.match(s) }
           else
             actual.include? exp_val
           end
      end)
    end

    # merge in field values from the new hash, with the following guarantees:
    #  values for keys in new_hash will be a non-empty String or flat Array
    #  keys will be removed from hash if all values are nil or empty
    def combine(new_hash)
      new_hash.select { |_key, value| Array(value).any? { |v| !v.blank? } }.each do |key, new_val|
        if field_present? key
          orig_val = self[key]
          case orig_val
          when Array
            self[key] += Array(new_val)
          else
            self[key] = Array(orig_val) + Array(new_val)
          end

          self[key] = self[key].reject(&:blank?).uniq
        else
          self[key] = new_val
        end
      end

      compact_blank_fields!

      self
    end

    def compact_blank_fields!
      keys.reject { |key| field_present? key }.each do |key|
        delete key
      end
      self
    end

    def druid
      self[:druid]
    end

    # validate fields that should be in hash for any item object in SearchWorks Solr
    # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
    def validate_item(config)
      result = validate_gdor_fields(config)
      result << "#{druid} missing collection\n" unless field_present?(:collection)

      Array(self[:collection]).each do |collection_druid|
        result << "#{druid} missing collection_with_title (or collection #{collection_druid} is missing title)\n" unless field_present?(:collection_with_title, Regexp.new("#{collection_druid}-\\|-.+"))
      end
      result << "#{druid} missing file_id(s)\n" unless field_present?(:file_id)
      result
    end

    # validate fields that should be in hash for any collection object in SearchWorks Solr
    # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
    def validate_collection(config)
      result = validate_gdor_fields(config)
      result << "#{druid} missing collection_type 'Digital Collection'\n" unless field_present?(:collection_type, 'Digital Collection')
      result << "#{druid} missing format_main_ssim 'Archive/Manuscript'\n" unless field_present?(:format_main_ssim, 'Archive/Manuscript')
      result
    end

    # validate fields that should be in hash for every gryphonDOR object in SearchWorks Solr
    # @return [Array<String>] Array of messages suitable for notificaiton email and/or logs
    def validate_gdor_fields(config)
      result = []
      result << "#{druid} missing druid field\n" unless field_present?(:druid, druid)
      result << "#{druid} missing url_fulltext for purl\n" unless field_present?(:url_fulltext, "#{config.harvestdor.purl}/#{druid}")
      result << "#{druid} missing access_facet 'Online'\n" unless field_present?(:access_facet, 'Online')
      result << "#{druid} missing or bad display_type, possibly caused by unrecognized @type attribute on <contentMetadata>\n" unless field_present?(:display_type, /(file)|(image)|(media)|(book)/)
      result << "#{druid} missing building_facet 'Stanford Digital Repository'\n" unless field_present?(:building_facet, 'Stanford Digital Repository')
      result
    end

    # validate fields that should be in doc hash for every unmerged gryphonDOR object in SearchWorks Solr
    # @return [Array<String>] array of Strings indicating absence of required fields
    def validate_mods(_config)
      result = []
      result << "#{druid} missing modsxml\n" unless field_present?(:modsxml)
      result << "#{druid} missing resource type\n" unless field_present?(:format_main_ssim)
      result << "#{druid} missing format\n" unless field_present?(:format) # for backwards compatibility
      result << "#{druid} missing title\n" unless field_present?(:title_display)
      result << "#{druid} missing pub year for date slider\n" unless field_present?(:pub_year_tisim)
      result << "#{druid} missing author\n" unless field_present?(:author_person_display)
      result << "#{druid} missing language\n" unless field_present?(:language)
      result
    end
  end
end
