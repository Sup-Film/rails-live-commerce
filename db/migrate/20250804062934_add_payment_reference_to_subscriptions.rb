class AddPaymentReferenceToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :subscriptions, :payment_reference, :string
    add_index :subscriptions, :payment_reference, unique: true
  end
end
