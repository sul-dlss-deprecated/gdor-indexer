$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'gdor/indexer'
require 'rspec/matchers' # req by equivalent-xml custom matcher `be_equivalent_to`
require 'equivalent-xml'
require 'vcr'
require 'stringio'

# for test coverage
require 'simplecov'
require 'simplecov-rcov'
class SimpleCov::Formatter::MergedFormatter
  def format(result)
     SimpleCov::Formatter::HTMLFormatter.new.format(result)
     SimpleCov::Formatter::RcovFormatter.new.format(result)
  end
end
SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
SimpleCov.start do
  # exclude from coverage
  add_filter "spec/"
  add_filter "config/deploy"
  add_filter "config/deploy.rb"
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
  c.configure_rspec_metadata!
end

#RSpec.configure do |config|
#end