class AddDefaultShippingProviderToUsers < ActiveRecord::Migration[7.1]
  def change
    add_reference :users, :default_shipping_provider, foreign_key: { to_table: :shipping_providers }
  end
end
