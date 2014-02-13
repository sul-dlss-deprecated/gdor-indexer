# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'dor-sw-indexer'
#set :repo_url, 'ssh://lyberadmin@corn.stanford.edu/afs/ir/dev/dlss/git/gryphondor/dor-sw-indexer'
#set :repo_url, 'ssh://corn.stanford.edu/afs/ir/dev/dlss/git/gryphondor/dor-sw-indexer'
#set :repo_url, '/afs/ir.stanford.edu/dev/dlss/git/gryphondor/dor-sw-indexer'
set :repo_url, 'file:///afs/ir.stanford.edu/dev/dlss/git/gryphondor/dor-sw-indexer.git'
set :user, "lyberadmin"

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# Default deploy_to directory is /var/www/my_app
set :deploy_to, "/home/#{fetch(:user)}/#{fetch(:application)}"

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/solr.yml, bin/index_prod_collections.sh bin/index_stage_collections.sh bin/index_university_archives.sh}

# Default value for linked_dirs is []
set :linked_dirs, %w(log logs config/collections tmp bin/log bin/logs)

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
#set :keep_releases, 5

set :stages, %W(dev stage prod)

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      #execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      # execute :rake, 'cache:clear'
      # end
    end
  end

end
