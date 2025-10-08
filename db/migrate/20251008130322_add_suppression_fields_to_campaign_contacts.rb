class AddSuppressionFieldsToCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_contacts, :suppressed, :boolean, default: false, null: false
    add_column :campaign_contacts, :suppression_reason, :text
    add_index :campaign_contacts, [:campaign_id, :suppressed]
  end
end
