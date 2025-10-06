class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :advertiser, null: false, foreign_key: true, index: true
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.references :contact, foreign_key: true, index: true
      t.string :external_id, null: false
      t.string :order_number
      t.string :email
      t.integer :financial_status
      t.integer :fulfillment_status
      t.string :currency, null: false
      t.decimal :subtotal, precision: 10, scale: 2
      t.decimal :total_tax, precision: 10, scale: 2
      t.decimal :total_discounts, precision: 10, scale: 2
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.jsonb :line_items, default: []
      t.jsonb :discount_codes, default: []
      t.jsonb :shipping_address
      t.jsonb :billing_address
      t.string :customer_locale
      t.string :tags, array: true, default: []
      t.text :note
      t.datetime :cancelled_at
      t.string :cancel_reason
      t.datetime :closed_at
      t.jsonb :metadata, default: {}
      t.datetime :ordered_at, null: false
      t.datetime :created_at_source
      t.datetime :updated_at_source
      t.timestamps
    end

    add_index :orders, [:advertiser_id, :ordered_at]
    add_index :orders, [:advertiser_id, :contact_id]
    add_index :orders, [:source_type, :source_id, :external_id], unique: true, name: 'idx_orders_source_external'
    add_index :orders, [:advertiser_id, :financial_status]
    add_index :orders, :line_items, using: :gin
  end
end
