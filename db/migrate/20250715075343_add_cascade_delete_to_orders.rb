class AddCascadeDeleteToOrders < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :orders, :products
    add_foreign_key :orders, :products
  end
end
