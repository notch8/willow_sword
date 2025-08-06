# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

def dockerized?
  File.exist?('/app/samvera/hyrax-webapp/config/environment.rb')
end

if dockerized?
  require '/app/samvera/hyrax-webapp/config/environment'
else
  require File.expand_path("../dummy/config/environment.rb", __FILE__)
end
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
# require 'rspec/autorun'

if dockerized?
  require 'database_cleaner/active_record'
  require 'factory_bot'
  require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'strategies', 'valkyrie_resource').to_s
  require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'users').to_s
  require Hyrax::Engine.root.join('lib', 'hyrax', 'specs', 'shared_specs', 'factories', 'hyrax_collection').to_s
  require Hyrax::Engine.root.join('spec', 'support', 'fakes', 'test_hydra_group_service').to_s

  FactoryBot.register_strategy(:valkyrie_create, ValkyrieCreateStrategy)
end

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# [...]
# configure shoulda matchers to use rspec as the test framework and full matcher libraries for rails
unless dockerized?
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end


RSpec.configure do |config|
  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  if dockerized?
    config.filter_run_including type: :request # only run request specs in docker

    config.include FactoryBot::Syntax::Methods
    config.use_transactional_fixtures = false

    config.before(:suite) do
      DatabaseCleaner.allow_remote_database_url = true
      DatabaseCleaner.clean_with(:truncation)
      User.group_service = TestHydraGroupService.new
    end

    config.before(:each) do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.start
    end

    config.append_after(:each) do
      DatabaseCleaner.clean
    end
  else
    #foo
    # [...]
    # add `FactoryGirl` methods
    config.include FactoryGirl::Syntax::Methods
    config.filter_run_excluding type: :request
  end
end
