class AddSuppressionSettingsToAdvertisers < ActiveRecord::Migration[8.0]
  def change
    add_column :advertisers, :recent_order_suppression_days, :integer, default: 0, null: false
    add_column :advertisers, :recent_mail_suppression_days, :integer, default: 0, null: false
    add_column :advertisers, :dnm_enabled, :boolean, default: true, null: false
  end
end
