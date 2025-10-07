class CreateAdvertiserAgencyAccesses < ActiveRecord::Migration[8.0]
  def change
    create_table :advertiser_agency_accesses do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.references :agency, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.datetime :invited_at
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :advertiser_agency_accesses, [:advertiser_id, :agency_id], unique: true, name: 'index_adv_agency_access_unique'
    add_index :advertiser_agency_accesses, :status
  end
end
