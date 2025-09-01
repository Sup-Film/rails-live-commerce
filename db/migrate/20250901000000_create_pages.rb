class CreatePages < ActiveRecord::Migration[7.0]
  def change
    create_table :pages do |t|
      t.string :page_id, null: false
      t.string :name
      t.text :access_token, null: false
      t.datetime :token_expires_at
      t.references :user, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :pages, :page_id, unique: true
  end
end
