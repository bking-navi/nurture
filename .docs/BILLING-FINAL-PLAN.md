# Prepaid Balance System - FINAL Implementation Plan

**Date**: October 7, 2025  
**Status**: APPROVED - Ready to Build  
**Estimated Effort**: 24-28 hours (3-4 days)

---

## ✅ Confirmed Requirements

### Pricing & Fees
- **Postcard Cost**: $1.05/card (breakeven, no markup for beta)
- **Stripe Fees**: Absorbed by us (2.9% + $0.30 per transaction)
- **Customer Deposits**: Clean amounts (customer pays $100, gets $100 balance)

### Balance Management
- **Low Balance Alerts**: Email when balance < $100 (configurable per advertiser)
- **Auto-Recharge**: Optional per advertiser
  - Enable/disable toggle
  - Trigger threshold (default: $100)
  - Recharge amount (default: $100)
  - Requires payment method on file

### Refunds
- **Manual Process**: Contact support only (we'll handle via Stripe dashboard)

---

## Updated Database Schema

### Additional Fields for Advertisers

```ruby
# Migration: add_billing_to_advertisers.rb
add_column :advertisers, :balance_cents, :integer, default: 0, null: false
add_column :advertisers, :stripe_customer_id, :string
add_column :advertisers, :payment_method_last4, :string
add_column :advertisers, :payment_method_brand, :string
add_column :advertisers, :payment_method_exp_month, :integer
add_column :advertisers, :payment_method_exp_year, :integer

# Low balance settings
add_column :advertisers, :low_balance_threshold_cents, :integer, default: 10000  # $100
add_column :advertisers, :low_balance_alert_sent_at, :datetime
add_column :advertisers, :low_balance_emails_enabled, :boolean, default: true

# Auto-recharge settings
add_column :advertisers, :auto_recharge_enabled, :boolean, default: false
add_column :advertisers, :auto_recharge_threshold_cents, :integer, default: 10000  # $100
add_column :advertisers, :auto_recharge_amount_cents, :integer, default: 10000  # $100
add_column :advertisers, :last_auto_recharge_at, :datetime

add_index :advertisers, :stripe_customer_id, unique: true
add_index :advertisers, :balance_cents
```

### Balance Transactions Table

```ruby
# Migration: create_balance_transactions.rb
create_table :balance_transactions do |t|
  t.references :advertiser, null: false, foreign_key: true
  t.string :transaction_type, null: false  # 'deposit', 'charge', 'auto_recharge'
  t.integer :amount_cents, null: false
  t.integer :balance_before_cents, null: false
  t.integer :balance_after_cents, null: false
  t.string :description, null: false
  
  # For deposits/auto-recharges
  t.string :stripe_payment_intent_id
  t.string :stripe_charge_id
  t.string :payment_method_last4
  t.integer :stripe_fee_cents  # Track fees we absorbed
  
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
```

---

## Updated Models

### Advertiser Model

```ruby
# app/models/advertiser.rb
class Advertiser < ApplicationRecord
  has_many :balance_transactions, dependent: :restrict_with_error
  
  # Balance methods
  def balance_dollars
    balance_cents / 100.0
  end
  
  def has_sufficient_balance?(amount_cents)
    balance_cents >= amount_cents
  end
  
  def can_send_campaign?(campaign)
    has_sufficient_balance?(campaign.estimated_cost_cents)
  end
  
  # Low balance management
  def low_balance_threshold_dollars
    low_balance_threshold_cents / 100.0
  end
  
  def below_low_balance_threshold?
    balance_cents < low_balance_threshold_cents
  end
  
  def should_send_low_balance_alert?
    return false unless low_balance_emails_enabled?
    return false unless below_low_balance_threshold?
    
    # Only send alert once per day
    low_balance_alert_sent_at.nil? || low_balance_alert_sent_at < 24.hours.ago
  end
  
  def mark_low_balance_alert_sent!
    update!(low_balance_alert_sent_at: Time.current)
  end
  
  # Auto-recharge management
  def auto_recharge_threshold_dollars
    auto_recharge_threshold_cents / 100.0
  end
  
  def auto_recharge_amount_dollars
    auto_recharge_amount_cents / 100.0
  end
  
  def should_auto_recharge?
    return false unless auto_recharge_enabled?
    return false unless payment_method_on_file?
    return false unless balance_cents < auto_recharge_threshold_cents
    
    # Prevent multiple rapid recharges
    last_auto_recharge_at.nil? || last_auto_recharge_at < 1.hour.ago
  end
  
  def attempt_auto_recharge!(system_user)
    return unless should_auto_recharge?
    
    service = StripePaymentService.new(self)
    
    # Get default payment method from Stripe customer
    customer = stripe_customer
    default_pm = customer.invoice_settings.default_payment_method
    
    intent = service.charge_and_add_funds(
      auto_recharge_amount_cents,
      default_pm,
      system_user,
      auto_recharge: true
    )
    
    update!(last_auto_recharge_at: Time.current)
    
    # Send success email
    BillingMailer.auto_recharge_success(self, auto_recharge_amount_dollars).deliver_later
    
    true
  rescue StripePaymentService::PaymentError => e
    # Log error and notify admins
    Rails.logger.error "Auto-recharge failed for advertiser #{id}: #{e.message}"
    BillingMailer.auto_recharge_failed(self, e.message).deliver_later
    
    # Disable auto-recharge to prevent repeated failures
    update!(auto_recharge_enabled: false)
    
    false
  end
  
  # Transaction methods
  def add_funds!(amount_cents, stripe_payment_intent_id:, processed_by:, payment_method_last4: nil, stripe_fee_cents: nil, auto_recharge: false)
    raise ArgumentError, "Amount must be positive" if amount_cents <= 0
    
    transaction do
      balance_before = balance_cents
      increment!(:balance_cents, amount_cents)
      balance_after = reload.balance_cents
      
      txn_type = auto_recharge ? 'auto_recharge' : 'deposit'
      description = auto_recharge ? 
        "Auto-recharge: #{ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)}" :
        "Funds added: #{ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)}"
      
      balance_transactions.create!(
        transaction_type: txn_type,
        amount_cents: amount_cents,
        balance_before_cents: balance_before,
        balance_after_cents: balance_after,
        description: description,
        stripe_payment_intent_id: stripe_payment_intent_id,
        payment_method_last4: payment_method_last4,
        stripe_fee_cents: stripe_fee_cents,
        processed_by: processed_by
      )
    end
  end
  
  def charge_for_campaign!(campaign, processed_by:)
    raise ArgumentError, "Campaign must have actual cost" unless campaign.actual_cost_cents > 0
    raise "Insufficient balance" unless has_sufficient_balance?(campaign.actual_cost_cents)
    
    transaction do
      balance_before = balance_cents
      decrement!(:balance_cents, campaign.actual_cost_cents)
      balance_after = reload.balance_cents
      
      balance_transactions.create!(
        transaction_type: 'charge',
        amount_cents: -campaign.actual_cost_cents,
        balance_before_cents: balance_before,
        balance_after_cents: balance_after,
        description: "Campaign sent: #{campaign.name}",
        campaign: campaign,
        postcards_count: campaign.sent_count,
        processed_by: processed_by
      )
      
      # Check if we should trigger auto-recharge or low balance alert
      check_balance_thresholds!(processed_by)
    end
  end
  
  def check_balance_thresholds!(user)
    # Try auto-recharge first
    if should_auto_recharge?
      attempt_auto_recharge!(user)
      return  # If auto-recharge succeeds, no need for low balance alert
    end
    
    # Send low balance alert if needed
    if should_send_low_balance_alert?
      BillingMailer.low_balance_alert(self).deliver_later
      mark_low_balance_alert_sent!
    end
  end
  
  # Stripe methods
  def stripe_customer
    return nil unless stripe_customer_id
    @stripe_customer ||= Stripe::Customer.retrieve(stripe_customer_id)
  end
  
  def create_stripe_customer!(user)
    return stripe_customer_id if stripe_customer_id
    
    customer = Stripe::Customer.create(
      email: user.email,
      name: name,
      metadata: {
        advertiser_id: id,
        advertiser_name: name
      }
    )
    
    update!(stripe_customer_id: customer.id)
    customer.id
  end
  
  def payment_method_summary
    return "No payment method" unless payment_method_last4
    "#{payment_method_brand.titleize} ••••#{payment_method_last4} (exp #{payment_method_exp_month}/#{payment_method_exp_year})"
  end
  
  def payment_method_on_file?
    stripe_customer_id.present? && payment_method_last4.present?
  end
end
```

### StripePaymentService Updates

```ruby
# app/services/stripe_payment_service.rb
class StripePaymentService
  def initialize(advertiser)
    @advertiser = advertiser
  end
  
  def charge_and_add_funds(amount_cents, payment_method_id, user, auto_recharge: false)
    raise ArgumentError, "Amount must be at least $5" if amount_cents < 500
    raise ArgumentError, "Amount must be at most $10,000" if amount_cents > 1_000_000
    
    # Create Stripe customer if needed
    @advertiser.create_stripe_customer!(user) unless @advertiser.stripe_customer_id
    
    # Calculate Stripe fee (we absorb it)
    stripe_fee = calculate_stripe_fee(amount_cents)
    total_to_charge = amount_cents + stripe_fee
    
    # Create payment intent
    intent = Stripe::PaymentIntent.create(
      amount: total_to_charge,  # Charge customer + fee
      currency: 'usd',
      customer: @advertiser.stripe_customer_id,
      payment_method: payment_method_id,
      off_session: true,
      confirm: true,
      description: auto_recharge ? 
        "Auto-recharge for #{@advertiser.name}" :
        "Balance top-up for #{@advertiser.name}",
      metadata: {
        advertiser_id: @advertiser.id,
        advertiser_name: @advertiser.name,
        user_id: user.id,
        user_email: user.email,
        balance_credit: amount_cents,  # The amount they get
        stripe_fee: stripe_fee,
        auto_recharge: auto_recharge
      }
    )
    
    # If successful, add funds to balance
    if intent.status == 'succeeded'
      @advertiser.add_funds!(
        amount_cents,  # Credit the requested amount
        stripe_payment_intent_id: intent.id,
        processed_by: user,
        payment_method_last4: @advertiser.payment_method_last4,
        stripe_fee_cents: stripe_fee,
        auto_recharge: auto_recharge
      )
    end
    
    intent
  rescue Stripe::CardError => e
    raise PaymentError, e.message
  rescue Stripe::StripeError => e
    raise PaymentError, "Payment failed: #{e.message}"
  end
  
  private
  
  def calculate_stripe_fee(amount_cents)
    # Stripe charges 2.9% + $0.30
    ((amount_cents * 0.029) + 30).ceil
  end
  
  class PaymentError < StandardError; end
end
```

---

## New Mailers

### BillingMailer

```ruby
# app/mailers/billing_mailer.rb
class BillingMailer < ApplicationMailer
  def low_balance_alert(advertiser)
    @advertiser = advertiser
    @balance = advertiser.balance_dollars
    @threshold = advertiser.low_balance_threshold_dollars
    @owner = advertiser.users.joins(:advertiser_memberships)
                      .where(advertiser_memberships: { role: 'owner' })
                      .first
    
    mail(
      to: @owner.email,
      subject: "Low Balance Alert - #{@advertiser.name}"
    )
  end
  
  def auto_recharge_success(advertiser, amount)
    @advertiser = advertiser
    @amount = amount
    @new_balance = advertiser.balance_dollars
    @owner = advertiser.users.joins(:advertiser_memberships)
                      .where(advertiser_memberships: { role: 'owner' })
                      .first
    
    mail(
      to: @owner.email,
      subject: "Auto-Recharge Successful - #{@advertiser.name}"
    )
  end
  
  def auto_recharge_failed(advertiser, error_message)
    @advertiser = advertiser
    @error = error_message
    @balance = advertiser.balance_dollars
    @owner = advertiser.users.joins(:advertiser_memberships)
                      .where(advertiser_memberships: { role: 'owner' })
                      .first
    
    mail(
      to: @owner.email,
      subject: "Auto-Recharge Failed - #{@advertiser.name}"
    )
  end
end
```

---

## Updated Controllers

### BillingController - Add Settings

```ruby
def index
  @balance = @advertiser.balance_dollars
  @transactions = @advertiser.balance_transactions.recent.page(params[:page]).per(50)
  @has_payment_method = @advertiser.payment_method_on_file?
  @settings = {
    low_balance_threshold: @advertiser.low_balance_threshold_dollars,
    low_balance_emails_enabled: @advertiser.low_balance_emails_enabled?,
    auto_recharge_enabled: @advertiser.auto_recharge_enabled?,
    auto_recharge_threshold: @advertiser.auto_recharge_threshold_dollars,
    auto_recharge_amount: @advertiser.auto_recharge_amount_dollars
  }
end

def update_settings
  settings_params = params.require(:billing_settings).permit(
    :low_balance_threshold_dollars,
    :low_balance_emails_enabled,
    :auto_recharge_enabled,
    :auto_recharge_threshold_dollars,
    :auto_recharge_amount_dollars
  )
  
  # Convert dollars to cents
  updates = {
    low_balance_threshold_cents: (settings_params[:low_balance_threshold_dollars].to_f * 100).to_i,
    low_balance_emails_enabled: settings_params[:low_balance_emails_enabled],
    auto_recharge_enabled: settings_params[:auto_recharge_enabled],
    auto_recharge_threshold_cents: (settings_params[:auto_recharge_threshold_dollars].to_f * 100).to_i,
    auto_recharge_amount_cents: (settings_params[:auto_recharge_amount_dollars].to_f * 100).to_i
  }
  
  # Validate auto-recharge requires payment method
  if updates[:auto_recharge_enabled] && !@advertiser.payment_method_on_file?
    flash[:error] = "Please add a payment method before enabling auto-recharge"
    return redirect_to billing_path(@advertiser.slug)
  end
  
  if @advertiser.update(updates)
    flash[:notice] = "Billing settings updated successfully"
  else
    flash[:error] = "Failed to update settings"
  end
  
  redirect_to billing_path(@advertiser.slug)
end
```

---

## Platform Admin Updates

### Show Fee Information

```ruby
# app/controllers/platform/admin/advertisers_controller.rb
def show
  @advertiser = Advertiser.find(params[:id])
  @members = @advertiser.advertiser_memberships.includes(:user).order(created_at: :asc)
  @agencies = @advertiser.advertiser_agency_accesses.includes(:agency)
  
  # Billing info
  @balance = @advertiser.balance_dollars
  @payment_method = @advertiser.payment_method_summary
  @recent_transactions = @advertiser.balance_transactions.recent.limit(10)
  @total_spent = @advertiser.balance_transactions.charges.sum(:amount_cents).abs / 100.0
  @total_deposited = @advertiser.balance_transactions.deposits.sum(:amount_cents) / 100.0
  @total_fees_absorbed = @advertiser.balance_transactions.sum(:stripe_fee_cents) / 100.0
end
```

---

## Routes Update

```ruby
scope 'advertisers/:advertiser_slug' do
  # Billing routes
  get 'billing', to: 'billing#index', as: :billing
  get 'billing/add-funds', to: 'billing#new_deposit', as: :new_deposit
  post 'billing/add-funds', to: 'billing#create_deposit', as: :create_deposit
  patch 'billing/settings', to: 'billing#update_settings', as: :update_billing_settings
  
  # Payment methods
  get 'billing/payment-method', to: 'payment_methods#edit', as: :edit_payment_method
  patch 'billing/payment-method', to: 'payment_methods#update', as: :update_payment_method
end
```

---

## Key Implementation Details

### 1. Stripe Fee Absorption

When customer deposits $100:
- We charge their card: $102.90 + $0.30 = $103.20
- They get: $100.00 credit
- We absorb: $3.20 in fees
- Tracked in `stripe_fee_cents` column

### 2. Auto-Recharge Flow

```
Campaign sent → Balance drops below threshold
  ↓
Check: auto_recharge_enabled? && payment_method_on_file?
  ↓ (yes)
Charge default payment method
  ↓
Success → Add funds, send success email
  ↓
Failure → Disable auto-recharge, send failure email
```

### 3. Low Balance Alert Flow

```
Campaign sent → Balance drops below threshold
  ↓
Check: low_balance_emails_enabled? && not sent in last 24h
  ↓ (yes)
Send low balance email
  ↓
Mark alert sent (prevents spam)
```

### 4. Campaign Send Flow

```
User clicks "Send Now"
  ↓
Calculate estimated cost
  ↓
Check: balance >= estimated_cost?
  ↓ (no) → Show error, prevent send
  ↓ (yes)
Send campaign via Lob
  ↓
Get actual costs from Lob
  ↓
Charge advertiser balance
  ↓
Check balance thresholds
  ↓
Trigger auto-recharge OR send low balance alert
```

---

## Testing Checklist

### Basic Flow
- [ ] Add payment method
- [ ] Deposit $100 → verify balance shows $100
- [ ] Send campaign → verify balance deducted
- [ ] Check transaction history shows both

### Auto-Recharge
- [ ] Enable auto-recharge
- [ ] Set threshold to $50, amount to $100
- [ ] Send campaigns until balance < $50
- [ ] Verify auto-recharge triggers
- [ ] Verify email sent
- [ ] Test with failed payment (expired card)
- [ ] Verify auto-recharge disabled on failure

### Low Balance Alerts
- [ ] Set threshold to $25
- [ ] Send campaigns until balance < $25
- [ ] Verify email sent
- [ ] Verify no duplicate emails within 24h
- [ ] Test with alerts disabled

### Edge Cases
- [ ] Try to send with insufficient balance
- [ ] Try auto-recharge without payment method
- [ ] Multiple rapid sends (prevent double-charge)
- [ ] Concurrent campaign sends

---

## Stripe Setup Instructions

### 1. Create Stripe Account
1. Go to https://dashboard.stripe.com/register
2. Sign up with your business email
3. Complete business verification (can use test mode first)

### 2. Get API Keys
1. Go to https://dashboard.stripe.com/test/apikeys
2. Copy your keys:
   - **Publishable key**: `pk_test_...`
   - **Secret key**: `sk_test_...` (click "Reveal test key")

### 3. Set Up Webhook
1. Go to https://dashboard.stripe.com/test/webhooks
2. Click "Add endpoint"
3. Enter URL: `https://your-app.onrender.com/webhooks/stripe`
4. Select events to listen for:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `customer.updated`
5. Copy the **Signing secret**: `whsec_...`

### 4. Add to Rails Credentials
```bash
EDITOR="code --wait" rails credentials:edit
```

Add:
```yaml
stripe:
  secret_key: sk_test_51...
  publishable_key: pk_test_...
  webhook_secret: whsec_...
```

### 5. Install Stripe Gem
```bash
bundle add stripe
```

### 6. Test Cards
Use these in test mode:
- **Success**: 4242 4242 4242 4242
- **Decline**: 4000 0000 0000 0002
- **Insufficient Funds**: 4000 0000 0000 9995

Any expiry date in the future, any CVC.

---

## Go Live Checklist (When Ready)

- [ ] Switch to live API keys
- [ ] Update webhook URL to production
- [ ] Complete Stripe business verification
- [ ] Set up bank account for payouts
- [ ] Test with real card (small amount)
- [ ] Enable Stripe Radar (fraud protection)
- [ ] Set up email receipts in Stripe dashboard

---

## Cost Summary

**Per $100 Customer Deposit:**
- Customer charged: $103.20
- Customer gets: $100.00 balance
- We absorb: $3.20 (Stripe fee)

**Per Campaign Send (100 postcards):**
- Customer charged: $105.00 (from balance)
- Lob charges us: ~$105.00
- Our margin: $0 (breakeven for beta)

**Monthly at 1,000 postcards sent:**
- Average deposits: ~10 × $100 = $1,000
- Stripe fees absorbed: ~$32
- Customer value: $1,050 in sends
- Our cost: $1,050 (Lob) + $32 (Stripe) = $1,082
- **Net: -$32/month per customer** (acceptable for beta)

---

Ready to start building! Any questions before I begin? 🚀

