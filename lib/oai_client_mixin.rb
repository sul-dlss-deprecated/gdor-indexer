# Monkey patch for OAI so we don't timeout
module OAI
  class Client
    
    # Do the actual HTTP get, following any temporary redirects
    def get(uri)
      max_retry = 5
      response = @http_client.get do |req|
        req.url uri
        req.options[:timeout] = 500           # open/read timeout in seconds
        req.options[:open_timeout] = 500      # connection open timeout in seconds
      end

      if response.status == 500 
        max_retry.times do
          puts "500 from OAI provider for #{uri.to_s}, retrying in 5 seconds"
          sleep(5)
          response = @http_client.get do |req|
            req.url uri
            req.options[:timeout] = 500           # open/read timeout in seconds
            req.options[:open_timeout] = 500      # connection open timeout in seconds
          end
          if response.status != 500
            break;
          end 
        end # max_retry
      end # 500

      if not response.success?
        raise "OAI provider returned an error code: #{response.status.to_s} \n#{response.body}"
      end
      
      response.body
    end # get method
   
  end # class Client
end # module OAI

