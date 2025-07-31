class AddEmailAndPasswordToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :email, :string unless column_exists?(:users, :email)
    
    add_column :users, :password_digest, :string unless column_exists?(:users, :password_digest)

    add_column :users, :image, :string unless column_exists?(:users, :image)

    change_column_null :users, :email, false
    add_index :users, :email, unique: true unless index_exists?(:users, :email, unique: true)
  end
end