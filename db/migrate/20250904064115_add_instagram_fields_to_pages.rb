class AddInstagramFieldsToPages < ActiveRecord::Migration[7.1]
  def change
    add_column :pages, :instagram_business_account_id, :string
  end
end
