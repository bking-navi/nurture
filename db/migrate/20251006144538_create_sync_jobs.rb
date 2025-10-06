class CreateSyncJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :sync_jobs do |t|
      t.references :advertiser, null: false, foreign_key: true, index: true
      t.references :shopify_store, null: false, foreign_key: true, index: true
      t.integer :job_type, null: false
      t.integer :status, default: 0, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :records_processed, default: {}
      t.jsonb :records_created, default: {}
      t.jsonb :records_updated, default: {}
      t.jsonb :records_failed, default: {}
      t.text :error_message
      t.jsonb :error_details, default: {}
      t.integer :estimated_duration
      t.integer :actual_duration
      t.integer :triggered_by, default: 0
      t.references :triggered_by_user, foreign_key: { to_table: :users }
      t.string :job_id  # Active Job ID (replaces sidekiq_jid)
      t.timestamps
    end

    add_index :sync_jobs, [:shopify_store_id, :created_at]
    add_index :sync_jobs, [:status, :created_at]
  end
end
