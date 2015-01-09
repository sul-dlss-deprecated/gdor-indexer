source 'https://rubygems.org'

# Specify your gem's dependencies in spotlight-dor-resources.gemspec
gemspec


# sul-gems
gem 'harvestdor-indexer', github: "sul-dlss/harvestdor-indexer", branch: "refactor"

group :deployment do
  gem "capistrano", '~> 3.2'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'    # gdor-indexer needs jruby for merged records
  gem "lyberteam-capistrano-devel"
  gem 'rainbow' # for color output
end
