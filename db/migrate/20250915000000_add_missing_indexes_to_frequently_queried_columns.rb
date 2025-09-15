class AddMissingIndexesToFrequentlyQueriedColumns < ActiveRecord::Migration[7.1]
  def change
    # Speeds up filtering and sorting orders by status and created time
    add_index :orders, [:status, :created_at]

    # Optimizes product lookup per user by productCode
    add_index :products, [:user_id, :productCode]

    # Improves retrieval of a user's credit ledger entries over time
    add_index :credit_ledgers, [:user_id, :created_at]
  end
end

