set :application, 'gdor-indexer'
set :repo_url, 'https://github.com/sul-dlss/gdor-indexer.git'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# gdor-indexer needs jruby until merge-manager
#set :rvm_ruby_version, "jruby-1.7.10"

set :user, "harvestdor"
set :deploy_to, "/opt/app/#{fetch(:user)}/#{fetch(:application)}"

set :linked_dirs, %w(logs config/collections tmp)
set :linked_files, %w{config/solr.yml bin/index-prod.sh bin/index-test.sh config/dor-fetcher-client.yml}

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
