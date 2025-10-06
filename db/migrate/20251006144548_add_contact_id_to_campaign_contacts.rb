class AddContactIdToCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaign_contacts, :contact, foreign_key: true, index: true
  end
end
