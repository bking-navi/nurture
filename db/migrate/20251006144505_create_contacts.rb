class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.references :advertiser, null: false, foreign_key: true, index: true
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.string :external_id, null: false
      t.string :email
      t.string :phone
      t.string :first_name
      t.string :last_name
      t.boolean :accepts_marketing, default: false
      t.datetime :accepts_marketing_updated_at
      t.string :marketing_opt_in_level
      t.string :tags, array: true, default: []
      t.text :note
      t.integer :state, default: 0
      t.decimal :total_spent, precision: 10, scale: 2, default: 0
      t.integer :orders_count, default: 0
      t.datetime :last_order_at
      t.datetime :first_order_at
      t.jsonb :default_address
      t.jsonb :addresses, default: []
      t.jsonb :metadata, default: {}
      t.datetime :created_at_source
      t.datetime :updated_at_source
      t.timestamps
    end

    add_index :contacts, [:advertiser_id, :email]
    add_index :contacts, [:source_type, :source_id, :external_id], unique: true, name: 'idx_contacts_source_external'
    add_index :contacts, :tags, using: :gin
    add_index :contacts, [:advertiser_id, :total_spent]
    add_index :contacts, [:advertiser_id, :last_order_at]
  end
end
