server 'harvestdor-dev.stanford.edu', user: 'harvestdor', roles: %w{web app db}

Capistrano::OneTimeKey.generate_one_time_key!

set :branch, "before-chris-mods"
