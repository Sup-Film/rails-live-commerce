class AddTrackingAndRefToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :tracking, :string
    add_column :orders, :ref, :string
  end
end
