class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :subscribed_at
      t.datetime :expires_at

      t.timestamps
    end
    add_index :subscriptions, :status
  end
end
