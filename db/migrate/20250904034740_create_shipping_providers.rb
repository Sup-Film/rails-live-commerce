class CreateShippingProviders < ActiveRecord::Migration[7.1]
  def change
    create_table :shipping_providers do |t|
      t.string :code
      t.string :name
      t.boolean :active

      t.timestamps
    end
    add_index :shipping_providers, :code, unique: true
  end
end
