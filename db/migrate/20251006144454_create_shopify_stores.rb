class CreateShopifyStores < ActiveRecord::Migration[8.0]
  def change
    create_table :shopify_stores do |t|
      t.references :advertiser, null: false, foreign_key: true, index: true
      t.string :shop_domain, null: false
      t.text :access_token, null: false  # Will be encrypted via model
      t.string :access_scopes, array: true, default: []
      t.string :name
      t.integer :status, default: 0, null: false
      t.datetime :last_sync_at
      t.integer :last_sync_status
      t.text :last_sync_error
      t.integer :sync_frequency, default: 2, null: false  # hourly default
      t.boolean :initial_sync_completed, default: false
      t.bigint :shopify_shop_id
      t.string :shop_owner
      t.string :email
      t.string :currency
      t.string :timezone
      t.string :plan_name
      t.boolean :webhooks_installed, default: false
      t.timestamps
    end

    add_index :shopify_stores, [:advertiser_id, :shop_domain], unique: true
  end
end
