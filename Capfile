#deploy for dor-sw-indexer

load 'deploy' if respond_to?(:namespace) # cap2 differentiator

require 'dlss/capistrano'



set :application, "dor-sw-indexer"
set :user, "lyberadmin"
set :repository,  "/afs/ir.stanford.edu/dev/dlss/git/gryphondor/dor-sw-indexer"
set :local_repository, "ssh://corn.stanford.edu#{repository}"
set :deploy_to, "/home/#{user}/#{application}"


# deploy to the test server with test and development gems for integration testing
task :dev do
  role :app, "harvestdor-dev.stanford.edu"
  set :deploy_env, "production"
end

task :stage do
  role :app, "harvestdor-stage.stanford.edu"
  set :deploy_env, "test"
end

task :production do
  role :app, "harvestdor-prod.stanford.edu"
  set :deploy_env, "production"
end

