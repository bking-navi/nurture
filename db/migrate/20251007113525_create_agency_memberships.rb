class CreateAgencyMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :agency, null: false, foreign_key: true
      t.string :role, default: 'viewer', null: false
      t.string :status, default: 'accepted', null: false
      t.datetime :invited_at
      t.datetime :accepted_at
      t.datetime :declined_at

      t.timestamps
    end
    add_index :agency_memberships, [:user_id, :agency_id], unique: true
    add_index :agency_memberships, :status
  end
end
