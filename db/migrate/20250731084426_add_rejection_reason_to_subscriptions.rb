class AddRejectionReasonToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_column :subscriptions, :rejection_reason, :text
  end
end
