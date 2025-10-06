class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :advertiser, null: false, foreign_key: true, index: true
      t.string :source_type, null: false
      t.bigint :source_id, null: false
      t.string :external_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :product_type
      t.string :vendor
      t.string :tags, array: true, default: []
      t.integer :status, default: 0
      t.jsonb :variants, default: []
      t.jsonb :images, default: []
      t.string :handle
      t.datetime :published_at
      t.jsonb :metadata, default: {}
      t.datetime :created_at_source
      t.datetime :updated_at_source
      t.timestamps
    end

    add_index :products, [:advertiser_id, :status]
    add_index :products, [:source_type, :source_id, :external_id], unique: true, name: 'idx_products_source_external'
    add_index :products, :tags, using: :gin
  end
end
