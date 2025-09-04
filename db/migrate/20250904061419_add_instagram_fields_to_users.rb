class AddInstagramFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :instagram_user_id, :string
    add_column :users, :instagram_username, :string
  end
end
