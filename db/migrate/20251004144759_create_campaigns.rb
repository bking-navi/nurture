class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      
      t.string :template_id
      t.string :template_name
      t.string :template_thumbnail_url
      t.text :front_message
      t.text :back_message
      t.text :merge_variables  # JSON serialized
      
      t.integer :estimated_cost_cents, default: 0
      t.integer :actual_cost_cents, default: 0
      t.integer :recipient_count, default: 0
      t.integer :sent_count, default: 0
      t.integer :failed_count, default: 0
      t.integer :delivered_count, default: 0
      
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :campaigns, [:advertiser_id, :status]
    add_index :campaigns, [:advertiser_id, :created_at]
  end
end
