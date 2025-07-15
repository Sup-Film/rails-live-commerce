class AddDeletedAtToProductsAndOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :deleted_at, :datetime
    add_index :products, :deleted_at
    add_column :orders, :deleted_at, :datetime
    add_index :orders, :deleted_at
  end
end
