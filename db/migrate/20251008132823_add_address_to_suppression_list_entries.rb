class AddAddressToSuppressionListEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :suppression_list_entries, :address_line1, :string
    add_column :suppression_list_entries, :address_line2, :string
    add_column :suppression_list_entries, :address_city, :string
    add_column :suppression_list_entries, :address_state, :string
    add_column :suppression_list_entries, :address_zip, :string
    
    # Remove unique constraint on email since we can now have address-only entries
    remove_index :suppression_list_entries, [:advertiser_id, :email]
    
    # Add compound index for address lookup
    add_index :suppression_list_entries, [:advertiser_id, :address_line1, :address_city, :address_state, :address_zip], 
              name: 'idx_suppression_on_address'
  end
end
