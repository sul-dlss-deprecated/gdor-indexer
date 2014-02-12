source 'https://rubygems.org'
source "http://sul-gems.stanford.edu"

# sul-gems
gem 'harvestdor-indexer'
gem 'harvestdor'
gem 'stanford-mods'
gem 'jruby-openssl'
gem 'nokogiri'
gem 'rake'
gem 'rsolr'
gem 'trollop'
gem 'solrmarc_wrapper'
gem 'solrj_wrapper', :git => "https://github.com/sul-dlss/solrj_wrapper.git", :branch => "solr4.4"
gem 'threach'
gem 'activesupport', '~> 3.0.0'
gem 'mail'
# documentation
group :doc do
	gem 'rdoc'
	gem 'yard'  # for javadoc-y documentation tags
end

# testing
group :test do
	gem 'rspec'
#	gem 'ruby-debug19'
	gem 'simplecov', :require => false
	gem 'simplecov-rcov', :require => false
#  gem 'jettywrapper'
  gem 'equivalent-xml'
end

group :deployment do
  gem "capistrano", '~> 3.0'
  gem 'capistrano-bundler', '~> 1.1'
  gem "lyberteam-capistrano-devel", '3.0.0.pre1'
  gem 'rainbow', '< 2.0'
end
