class AddBillingToAdvertisers < ActiveRecord::Migration[8.0]
  def change
    # Balance tracking
    add_column :advertisers, :balance_cents, :integer, default: 0, null: false
    
    # Stripe integration
    add_column :advertisers, :stripe_customer_id, :string
    add_column :advertisers, :payment_method_last4, :string
    add_column :advertisers, :payment_method_brand, :string
    add_column :advertisers, :payment_method_exp_month, :integer
    add_column :advertisers, :payment_method_exp_year, :integer
    
    # Low balance alerts
    add_column :advertisers, :low_balance_threshold_cents, :integer, default: 10000  # $100
    add_column :advertisers, :low_balance_alert_sent_at, :datetime
    add_column :advertisers, :low_balance_emails_enabled, :boolean, default: true
    
    # Auto-recharge
    add_column :advertisers, :auto_recharge_enabled, :boolean, default: false
    add_column :advertisers, :auto_recharge_threshold_cents, :integer, default: 10000  # $100
    add_column :advertisers, :auto_recharge_amount_cents, :integer, default: 10000  # $100
    add_column :advertisers, :last_auto_recharge_at, :datetime
    
    # Indexes
    add_index :advertisers, :stripe_customer_id, unique: true
    add_index :advertisers, :balance_cents
  end
end
