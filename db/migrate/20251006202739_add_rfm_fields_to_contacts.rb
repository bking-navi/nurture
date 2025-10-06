class AddRfmFieldsToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :average_order_value, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :contacts, :rfm_recency_score, :integer, default: 0
    add_column :contacts, :rfm_frequency_score, :integer, default: 0
    add_column :contacts, :rfm_monetary_score, :integer, default: 0
    add_column :contacts, :rfm_segment, :string
    
    # Add indexes for filtering and sorting by RFM scores
    add_index :contacts, [:advertiser_id, :rfm_recency_score]
    add_index :contacts, [:advertiser_id, :rfm_frequency_score]
    add_index :contacts, [:advertiser_id, :rfm_monetary_score]
    add_index :contacts, [:advertiser_id, :rfm_segment]
  end
end
