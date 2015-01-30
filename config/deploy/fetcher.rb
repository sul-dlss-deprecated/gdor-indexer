# Temporary deployment target for DorFetcher work
server 'harvestdor-dev.stanford.edu', user: 'harvestdor', roles: %w{app}

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_to, "/opt/app/#{fetch(:user)}/gdor-indexer-fetcher"
