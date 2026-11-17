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

### SWORD link host behind a proxy
By default SWORD links (service document collection hrefs, `edit`, `edit-media`, `related` and `Location` headers) use the request host. If a proxy rewrites `Host` (for example so a multi-tenant app can resolve the tenant) and passes the host the client called in another header, name that header and list the hosts it may carry:

```ruby
WillowSword.setup do |config|
  config.sword_host_header = 'X-Sword-Host'
  config.sword_allowed_hosts = ['sword.example.org']
end
```

The header is ignored, and the request host used, unless its value is a bare hostname that exactly matches (case-insensitively) an entry in `sword_allowed_hosts`. Clients can send any header they like, so without the allow-list a client could put its own host into the links. Both settings default to off (`nil` and `[]`), which leaves links unchanged. Content links (work pages, file downloads) always stay on the request host.

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

### Request specs

Request specs boot up a Hyrax instance inside a docker environment and run test against it.

```sh
docker compose up -d
# wait for the web service to finish booting up the Hyrax instance

cd /willow_sword
rspec
```

#### Troubleshooting
If you're getting a platform error when trying to up the containers, try adding
`platform: linux/amd64` to the `web` service.

Ex.
```yml
services:
  web:
    platform: linux/amd64
```
