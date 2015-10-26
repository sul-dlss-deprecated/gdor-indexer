$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

# for test coverage
require 'simplecov'
SimpleCov.start do
  # exclude from coverage
  add_filter 'spec/'
  add_filter 'config/deploy'
  add_filter 'config/deploy.rb'
end

require 'gdor/indexer'
require 'rspec/matchers' # req by equivalent-xml custom matcher `be_equivalent_to`
require 'equivalent-xml'
require 'vcr'
require 'stringio'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
  c.configure_rspec_metadata!
end

# RSpec.configure do |config|
# end
