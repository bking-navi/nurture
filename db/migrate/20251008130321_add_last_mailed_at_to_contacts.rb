class AddLastMailedAtToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :last_mailed_at, :datetime
    add_index :contacts, [:advertiser_id, :last_mailed_at]
  end
end
