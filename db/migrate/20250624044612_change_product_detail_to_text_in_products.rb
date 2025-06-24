class ChangeProductDetailToTextInProducts < ActiveRecord::Migration[7.1]
  def change
    change_column :products, :productDetail, :text
  end
end
