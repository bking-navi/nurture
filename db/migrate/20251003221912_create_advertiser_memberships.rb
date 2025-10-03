class CreateAdvertiserMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :advertiser_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :advertiser, null: false, foreign_key: true
      t.string :role, null: false, default: 'viewer'
      t.string :status, null: false, default: 'accepted'

      t.timestamps
    end
    
    # Ensure a user can only have one membership per advertiser
    add_index :advertiser_memberships, [:user_id, :advertiser_id], unique: true
    add_index :advertiser_memberships, :status
  end
end
