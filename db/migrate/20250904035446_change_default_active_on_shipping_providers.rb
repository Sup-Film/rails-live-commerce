class ChangeDefaultActiveOnShippingProviders < ActiveRecord::Migration[7.1]
  def change
    change_column_default :shipping_providers, :active, from: nil, to: true
  end
end
