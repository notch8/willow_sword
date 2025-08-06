class AddAPIKeyToUsers < ActiveRecord::Migration[<%= Rails::VERSION::MAJOR %>.<%= Rails::VERSION::MINOR %>]
  def change
    add_column :users, :api_key, :string unless column_exists?(:users, :api_key)
    add_index :users, :api_key unless index_exists?(:users, :api_key)
  end
end
