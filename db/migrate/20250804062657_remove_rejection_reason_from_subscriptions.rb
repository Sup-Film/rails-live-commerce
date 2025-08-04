class RemoveRejectionReasonFromSubscriptions < ActiveRecord::Migration[7.1]
  def change
    remove_column :subscriptions, :rejection_reason, :text
  end
end
