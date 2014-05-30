# Temporary deployment target for SW UI redesign work (v2.6 of solrmarc)
server 'harvestdor-dev.stanford.edu', user: 'lyberadmin', roles: %w{app}

Capistrano::OneTimeKey.generate_one_time_key!

set :deploy_to, "/home/#{fetch(:user)}/gdor-indexer-swuird"
# temporary:  use item-level-merge branch on harvestdor-dev!
set :branch, "swuird"
# temporary:  scripts for groups of collections
set :linked_files, %w{.ruby-version config/solr.yml bin/index_prod_collections.sh bin/index_stage_collections.sh bin/index-prod-image.sh bin/index-prod-hydrus.sh}
