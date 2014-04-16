# Monkey patch for solrj_wrapper to fix solr4.4 issues. They are also fixed in the solr4.4 branch of solrj_wrapper
class SolrjWrapper
  def initialize(solrj_jar_dir, solr_url, queue_size, num_threads, log_level=Logger::INFO, log_file=STDERR)
    if not defined? JRUBY_VERSION
      raise "SolrjWrapper only runs under jruby"
    end
    @logger = Logger.new(log_file)
    @logger.level = log_level
    load_solrj(solrj_jar_dir)
    @query_server = org.apache.solr.client.solrj.impl.HttpSolrServer.new(solr_url)
    @streaming_update_server = @query_server 
  end
end
