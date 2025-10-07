class CreateLobApiLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :lob_api_logs do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.references :campaign, null: true, foreign_key: true
      t.string :endpoint, null: false
      t.string :method, null: false
      t.json :request_body
      t.json :response_body
      t.integer :status_code
      t.boolean :success, default: false, null: false
      t.text :error_message
      t.integer :duration_ms
      t.integer :cost_cents, default: 0
      t.string :lob_object_id
      t.string :lob_object_type

      t.timestamps
    end
    
    add_index :lob_api_logs, :created_at
    add_index :lob_api_logs, :success
    add_index :lob_api_logs, :lob_object_id
    add_index :lob_api_logs, [:advertiser_id, :created_at]
    add_index :lob_api_logs, [:campaign_id, :created_at]
  end
end
