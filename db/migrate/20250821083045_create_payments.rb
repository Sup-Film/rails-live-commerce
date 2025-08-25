class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.integer :amount_cents, null: false, default: 0
      t.string :external_ref
      t.jsonb :metadata, default: {}
      t.string :payable_type, null: false
      t.bigint :payable_id, null: false
      t.string :status, null: false, default: "pending"

      # verified_by references to users (optional)
      t.references :verified_by, foreign_key: { to_table: :users }, index: true, null: true
      t.datetime :verified_at

      t.timestamps
    end

    add_index :payments, :external_ref, unique: true
    add_index :payments, [:payable_type, :payable_id]
  end
end
