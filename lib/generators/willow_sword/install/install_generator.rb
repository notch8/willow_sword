# frozen_string_literal: true

module WillowSword
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def add_routes
        route "  mount WillowSword::Engine => '/sword'"
      end

      def create_api_key_migration
        migration_template "add_api_key_to_users.rb", "db/migrate/add_api_key_to_users.rb"
      end
    end
  end
end
