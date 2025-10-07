class CreateAgencies < ActiveRecord::Migration[8.0]
  def change
    create_table :agencies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :street_address, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :postal_code, null: false
      t.string :country, default: 'US', null: false
      t.string :website_url, null: false
      t.text :settings

      t.timestamps
    end
    add_index :agencies, :slug, unique: true
    add_index :agencies, :name
  end
end
