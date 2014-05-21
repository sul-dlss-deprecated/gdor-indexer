require 'solrmarc_wrapper'
require 'solrj_wrapper'

class RecordMerger
  
  def self.fetch_sw_solr_input_doc catkey
    @sw_solr_input_doc = smwrapper.get_solr_input_doc_from_marcxml(catkey)
  end
  
  # @param [SolrInputDocumnet] solr_input_doc - java SolrInputDocument per solrj; the solr document object
  # @param [Hash<String, Object>] field_hash the keys are Solr field names, the values are either String or an Array of Strings
  def self.add_hash_to_solr_input_doc solr_input_doc, field_hash
    field_hash.each_pair { |name, val| 
      name = name.to_s if name.is_a?(Symbol) 
      if val.is_a?(String)
        solrj.add_val_to_fld(solr_input_doc, name, val)
      elsif val.is_a?(Array)
        val.each { |v|  
          solrj.add_val_to_fld(solr_input_doc, name, v)
        }
      else
        raise "hash to add to merged solr document has incorrectly typed field value for #{name}: #{field_hash.inspect}"
      end
    }
  end
  
  # @param [String] catkey - the Symphony record catkey of the record we will be merging with
  # @param [Hash<String, Object>] doc_hash_to_add - the keys are Solr field names, the values are either String or an Array of Strings
  def self.merge_and_index catkey, doc_hash_to_add
    doc = RecordMerger.fetch_sw_solr_input_doc catkey
    if !doc
      if Indexer.config.merge_policy == 'always'
        Indexer.logger.error("#{doc_hash_to_add[:druid]} NOT INDEXED:  MARC record #{catkey} not found in SW Solr index (may be shadowed in Symphony)")
      else
        Indexer.logger.error("#{doc_hash_to_add[:druid]} indexed from MODS:  MARC record #{catkey} not found in SW Solr index (may be shadowed in Symphony)")
      end
      return false
    end
    add_hash_to_solr_input_doc(doc, doc_hash_to_add)
    solrj.add_doc_to_ix(doc, catkey)
    true
  end
  
  # cache SolrJWrapper object at class level
  def self.solrj
    @@solrj ||= SolrjWrapper.new('../solrmarc-sw/lib/solrj-lib', Indexer.config.solr.url, 1, 1)
  end
  
  # cache SolrmarcWrapper object at class level
  def self.smwrapper
    @@smwrapper ||= begin
      dist_dir = Indexer.config.solrmarc.dist_dir
      sw_solr_url = Indexer.config.solrmarc.sw_solr_url
      config_file = Indexer.config.solrmarc.config_file
      SolrmarcWrapper.new(dist_dir, config_file, sw_solr_url)
    end
  end

end