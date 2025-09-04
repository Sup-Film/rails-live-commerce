class CreateInstagramMedia < ActiveRecord::Migration[7.1]
  def change
    create_table :instagram_media do |t|
      t.string :instagram_media_id
      t.string :media_type
      t.text :caption
      t.string :media_url
      t.string :permalink
      t.datetime :timestamp
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
