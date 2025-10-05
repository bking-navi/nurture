class AddTemplateFieldsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :postcard_template_id, :integer
    add_column :campaigns, :template_data, :text  # JSON: stores customized field values
    add_column :campaigns, :color_palette_id, :integer
    
    add_index :campaigns, :postcard_template_id
    add_index :campaigns, :color_palette_id
    add_foreign_key :campaigns, :postcard_templates, on_delete: :nullify
    add_foreign_key :campaigns, :color_palettes, on_delete: :nullify
  end
end
