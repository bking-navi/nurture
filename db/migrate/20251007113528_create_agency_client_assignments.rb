class CreateAgencyClientAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_client_assignments do |t|
      t.references :agency_membership, null: false, foreign_key: true
      t.references :advertiser_agency_access, null: false, foreign_key: true
      t.string :role, default: 'viewer', null: false

      t.timestamps
    end
    add_index :agency_client_assignments, [:agency_membership_id, :advertiser_agency_access_id], 
              unique: true, 
              name: 'index_agency_client_assignments_unique'
  end
end
