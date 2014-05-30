source 'https://rubygems.org'
source "http://sul-gems.stanford.edu"

# sul-gems
gem 'harvestdor-indexer'
gem 'harvestdor'
gem 'stanford-mods', :git => "https://github.com/sul-dlss/stanford-mods.git", :branch => "new-formats"
gem 'jruby-openssl'
gem 'nokogiri'
gem 'rake'
gem 'rsolr'
gem 'trollop'
gem 'solrmarc_wrapper'
gem 'solrj_wrapper'
gem 'threach'
gem 'activesupport'
gem 'mail'
gem 'faraday', '~>0.8.9' # 0.9.0 doesn't play nicely with oai/harvestdor gem

# documentation
group :doc do
	gem 'rdoc'
	gem 'yard'  # for javadoc-y documentation tags
end

# testing
group :test do
	gem 'rspec'
	gem 'simplecov', :require => false
	gem 'simplecov-rcov', :require => false
#  gem 'jettywrapper'
  gem 'equivalent-xml', '0.4.0' # 0.4.1 causes a failure 
end

group :deployment do
  gem "capistrano", '~> 3.2'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'    # gdor-indexer needs jruby until merge-manager
  gem "lyberteam-capistrano-devel", '3.0.0.pre1'
  gem 'rainbow' # for color output
end
