class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :image
      t.string :productName
      t.string :productDetail
      t.decimal :productPrice
      t.integer :productCode

      t.timestamps
    end
  end
end
