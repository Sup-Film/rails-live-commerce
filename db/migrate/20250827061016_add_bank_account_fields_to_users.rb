class AddBankAccountFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :bank_account_number, :string
    add_column :users, :bank_account_name, :string
    add_column :users, :bank_code, :string
  end
end
