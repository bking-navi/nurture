class CreateColorPalettes < ActiveRecord::Migration[8.0]
  def change
    create_table :color_palettes do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :colors, null: false  # JSON: {primary: "#FF0000", secondary: "#00FF00", ...}
      t.integer :advertiser_id  # NULL = global/default palette
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end
    
    add_index :color_palettes, :slug
    add_index :color_palettes, :advertiser_id
    add_index :color_palettes, :is_default
    add_foreign_key :color_palettes, :advertisers, on_delete: :cascade
  end
end
