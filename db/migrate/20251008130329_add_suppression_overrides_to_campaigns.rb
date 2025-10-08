class AddSuppressionOverridesToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :recent_order_suppression_days, :integer
    add_column :campaigns, :recent_mail_suppression_days, :integer
    add_column :campaigns, :override_suppression, :boolean, default: false, null: false
  end
end
