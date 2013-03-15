require 'solrmarc_wrapper'
require 'solrj_wrapper'
class RecordMerger
  def self.fetch_sw_solr_input_doc
    dist_dir = Indexer.config.solrmarc.dist_dir
    sw_solr_url = Indexer.config.solrmarc.sw_solr_url
    puts sw_solr_url
    config_file = Indexer.config.solrmarc.config_file
    puts config_file.to_s
    smwrapper = SolrmarcWrapper.new(dist_dir, config_file, sw_solr_url)
    @sw_solr_input_doc = smwrapper.get_solr_input_doc_from_marcxml(@catkey)
  end
  def self.merge druid, catkey
    @catkey=catkey
    @druid=druid
    doc=RecordMerger.fetch_sw_solr_input_doc
    solrj = SolrjWrapper.new('../solrmarc-sw/lib/solrj-lib',Indexer.config.solr.url,1,1)
    solrj.add_val_to_fld(doc, "url_fulltext", 'new purl!')
    solrj.add_val_to_fld(doc, "access_facet", "Online")

    #at the moment we  only merge collections, this will have to check for item vs collection in the future
    solrj.add_val_to_fld(doc, "collection_type", "Digital Collection")
    solrj.add_doc_to_ix(doc, @catkey)
    solrj.commit
  end
  def print doc
    doc.keys.each do |key|
      val=doc[key].getValue
      if val.respond_to? :each
        newval=''
        val.each do |f|
          newval+= f
        end
        val=newval
      end
      puts 'key:'+key+" | val:" + val
    end
  end
end