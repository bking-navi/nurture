class CreateAgencyInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :agency_invitations do |t|
      t.references :agency, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, null: false, default: 'viewer'
      t.string :status, null: false, default: 'pending'
      t.string :token, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end
    
    add_index :agency_invitations, :token, unique: true
    add_index :agency_invitations, [:agency_id, :email]
    add_index :agency_invitations, :status
  end
end
