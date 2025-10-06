class CreateCreatives < ActiveRecord::Migration[8.0]
  def change
    create_table :creatives do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.references :postcard_template, null: false, foreign_key: true
      t.bigint :created_by_user_id
      t.bigint :created_from_campaign_id
      
      t.string :name, null: false
      t.text :description
      t.string :tags, array: true, default: []
      t.integer :usage_count, default: 0
      t.datetime :last_used_at
      t.string :status, default: 'active'

      t.timestamps
    end
    
    # Add foreign keys with custom names
    add_foreign_key :creatives, :users, column: :created_by_user_id
    add_foreign_key :creatives, :campaigns, column: :created_from_campaign_id
    
    # Add indexes
    add_index :creatives, [:advertiser_id, :status]
    add_index :creatives, :tags, using: 'gin'
    add_index :creatives, :usage_count
    add_index :creatives, :created_by_user_id
    add_index :creatives, :created_from_campaign_id
  end
end
