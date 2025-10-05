class CreateCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_contacts do |t|
      t.references :campaign, null: false, foreign_key: true
      
      # Recipient info
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :company
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :address_city, null: false
      t.string :address_state, null: false
      t.string :address_zip, null: false
      t.string :address_country, default: 'US'
      t.string :email
      t.string :phone
      t.text :metadata  # JSON serialized
      
      # Lob tracking
      t.string :lob_postcard_id
      t.integer :status, default: 0, null: false
      t.integer :estimated_cost_cents, default: 0
      t.integer :actual_cost_cents, default: 0
      t.string :tracking_number
      t.string :tracking_url
      t.date :expected_delivery_date
      t.datetime :delivered_at
      t.text :send_error
      t.text :lob_response  # JSON serialized
      
      t.timestamps
    end
    
    add_index :campaign_contacts, [:campaign_id, :status]
    add_index :campaign_contacts, [:campaign_id, :created_at]
    add_index :campaign_contacts, :lob_postcard_id, unique: true
  end
end
