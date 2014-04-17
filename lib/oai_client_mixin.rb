# Monkey patch for OAI so we don't timeout
module OAI
  class Client
    
    # Do the actual HTTP get, following any temporary redirects
    def get(uri)
      # open/read timeout in milliseconds
      timeout_ms = Indexer.config.http_options.timeout 
      timeout_ms ||= 500
      # connection open timeout in milliseconds
      conn_timeout_ms = Indexer.config.http_options.open_timeout 
      conn_timeout_ms ||= 500

      response = @http_client.get do |req|
        req.url uri
        req.options[:timeout] = timeout_ms
        req.options[:open_timeout] = conn_timeout_ms
      end

      max_retry = 5
      if response.status == 500 
        max_retry.times do
          puts "HTTP 500 error from OAI provider #{uri.to_s}, retrying in 3 seconds"
          sleep(3)
          response = @http_client.get do |req|
            req.url uri
            req.options[:timeout] = timeout_ms
            req.options[:open_timeout] = conn_timeout_ms
          end
          if response.status != 500
            break;
          end 
        end # max_retry.times
      end # 500 response

      if not response.success?
        raise "OAI provider returned an error code: #{response.status.to_s} \n#{response.body}"
      end
      
      response.body
    end # get method
   
  end # class Client
end # module OAI

