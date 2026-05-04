#!/bin/sh
set -e

# Add willow_sword gem if not already present
if ! grep -q "gem 'willow_sword'" Gemfile; then
  echo "Adding willow_sword gem to Gemfile..."
  echo "gem 'willow_sword', path: '/willow_sword'" >> Gemfile
fi

echo "Running bundle install..."
BUNDLE_GEMFILE=Gemfile.dassie bundle install

echo "Running willow_sword install generator..."
bundle exec rails generate willow_sword:install

echo "Creating and migrating database..."
bundle exec rails db:create db:migrate

echo "Initialization complete!"
