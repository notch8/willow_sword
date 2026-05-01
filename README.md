# WillowSword
A Ruby on Rails engine for the Sword V2 server. The Sword server is currently integrated with Hyrax V2.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'willow_sword', git: 'https://github.com/CottageLabs/willow_sword.git'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install willow_sword
```

Mount the engine. Add this line to config/routes.rb

```ruby
mount WillowSword::Engine => '/sword'
```

Or run the generator

```sh
bundle exec rails generate willow_sword:install
```

## Configuration
The plugin has a few configuration options. To view the current default options and override these, see [configuration options](https://github.com/CottageLabs/willow_sword/wiki/Configuring-willow-sword)

## Enable authorization
If you would like to authorize all Sword requests using an Api-key header, see [Enabling authorization](https://github.com/CottageLabs/willow_sword/wiki/Enabling-Authorization-In-Willow-Sword)

## Usage
To use the plugin see [usage](https://github.com/CottageLabs/willow_sword/wiki/Usage).

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Testing

### Legacy tests

```sh
bundle install
rspec
```

### Request specs (default Dassie)

Request specs boot up a Hyrax Dassie instance inside a docker environment and run tests against it.

```sh
docker compose up -d --build web
# wait for Puma to finish booting (~2-3 minutes)

docker compose exec -w /willow_sword web \
  bash -lc 'BUNDLE_GEMFILE=/app/samvera/hyrax-webapp/Gemfile.dassie bundle exec rspec'
```

### Request specs (flexible metadata)

To run against Dassie with flexible metadata (`HYRAX_FLEXIBLE=true`):

```sh
docker compose -f docker-compose.yml -f docker-compose.flexible.yml up -d --build web
# wait for Puma to finish booting (~2-3 minutes)

docker compose -f docker-compose.yml -f docker-compose.flexible.yml \
  exec -w /willow_sword web \
  bash -lc 'BUNDLE_GEMFILE=/app/samvera/hyrax-webapp/Gemfile.dassie bundle exec rspec'
```

### Updating the Hyrax dev image

The integration tests use a pre-built Hyrax dev image (`ghcr.io/samvera/hyrax-dev`). To update it, run the "Build Hyrax Dev Image" workflow from the Actions tab with the desired Hyrax commit SHA. This publishes a new image to `ghcr.io/notch8/hyrax-dev` and the `Dockerfile` can then be updated to reference it.

#### Troubleshooting
If you're getting a platform error when trying to up the containers, try adding
`platform: linux/amd64` to the `web` service.

Ex.
```yml
services:
  web:
    platform: linux/amd64
```
