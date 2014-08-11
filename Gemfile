source 'https://rubygems.org'

# sul-gems
gem 'harvestdor-indexer', '>=0.0.13'
gem 'harvestdor', '>=0.0.14'
gem 'stanford-mods'
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
  gem 'capistrano-rvm'    # gdor-indexer needs jruby for merged records
  gem "lyberteam-capistrano-devel"
  gem 'rainbow' # for color output
end
