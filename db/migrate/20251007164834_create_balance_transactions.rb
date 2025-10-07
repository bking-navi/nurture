class CreateBalanceTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :balance_transactions do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.integer :amount_cents, null: false
      t.integer :balance_before_cents, null: false
      t.integer :balance_after_cents, null: false
      t.string :description, null: false
      
      # For deposits/auto-recharges
      t.string :stripe_payment_intent_id
      t.string :stripe_charge_id
      t.string :payment_method_last4
      t.integer :stripe_fee_cents, default: 0
      
      # For charges
      t.references :campaign, foreign_key: true
      t.integer :postcards_count
      
      # Metadata
      t.references :processed_by, foreign_key: { to_table: :users }
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    add_index :balance_transactions, :transaction_type
    add_index :balance_transactions, :stripe_payment_intent_id
    add_index :balance_transactions, :created_at
    add_index :balance_transactions, [:advertiser_id, :created_at]
  end
end
