class CreateThirdParties < ActiveRecord::Migration[7.0]
  def change
    create_table :third_parties do |t|
      t.string :name
      t.string :slug
      t.boolean :enabled
      t.text :token
      t.datetime :token_expire
      t.timestamps
    end
  end
end
