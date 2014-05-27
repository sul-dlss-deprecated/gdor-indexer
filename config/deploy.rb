set :application, 'gdor-indexer'
set :repo_url, 'https://github.com/sul-dlss/gdor-indexer.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# gdor-indexer needs jruby until merge-manager
set :rvm_ruby_version, "jruby-1.7.10"

set :user, "lyberadmin"
set :deploy_to, "/home/#{fetch(:user)}/#{fetch(:application)}"

set :linked_dirs, %w(logs config/collections tmp solrmarc-sw)
set :linked_files, %w{.ruby-version config/solr.yml bin/index_prod_collections.sh bin/index_stage_collections.sh}

set :stages, %W(dev stage prod)

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :pty is false
# set :pty, true

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 10
