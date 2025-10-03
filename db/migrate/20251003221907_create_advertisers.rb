class CreateAdvertisers < ActiveRecord::Migration[8.0]
  def change
    create_table :advertisers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :street_address, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :postal_code, null: false
      t.string :country, null: false, default: 'US'
      t.string :website_url, null: false
      t.text :settings  # JSON serialized for SQLite, will be jsonb in PostgreSQL

      t.timestamps
    end
    add_index :advertisers, :slug, unique: true
    add_index :advertisers, :name
  end
end
