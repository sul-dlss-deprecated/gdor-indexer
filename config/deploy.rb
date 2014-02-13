# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'gdor-indexer'
set :repo_url, 'https://github.com/sul-dlss/gdor-indexer.git'
set :user, "lyberadmin"

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

set :deploy_to, "/home/#{fetch(:user)}/#{fetch(:application)}"

set :linked_dirs, %w(log logs config/collections tmp bin/log bin/logs)
#set :linked_files, %w{config/solr.yml, bin/index_prod_collections.sh bin/index_stage_collections.sh bin/index_university_archives.sh}

set :stages, %W(dev stage prod)

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
#set :keep_releases, 5

namespace :deploy do
end