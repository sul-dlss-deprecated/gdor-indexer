# Temporary deployment target for DorFetcher work
server 'harvestdor-dev.stanford.edu', user: 'lyberadmin', roles: %w(app)

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_to, "/home/#{fetch(:user)}/gdor-indexer-fetcher"
