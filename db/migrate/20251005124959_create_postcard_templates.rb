class CreatePostcardTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :postcard_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :category, null: false
      t.string :thumbnail_url
      t.string :preview_url
      t.text :front_html, null: false
      t.text :back_html, null: false
      t.text :front_css
      t.text :back_css
      t.text :front_fields  # JSON
      t.text :back_fields   # JSON
      t.text :default_values  # JSON
      t.boolean :active, default: true, null: false
      t.integer :sort_order, default: 0, null: false

      t.timestamps
    end
    
    add_index :postcard_templates, :slug, unique: true
    add_index :postcard_templates, :category
    add_index :postcard_templates, :sort_order
    add_index :postcard_templates, :active
  end
end
