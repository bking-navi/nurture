# Prepaid Balance System - Implementation Plan

**Date**: October 7, 2025  
**Priority**: 🔴 CRITICAL - Required for Launch  
**Estimated Effort**: 20-24 hours (2-3 days)  
**Status**: READY TO BUILD

---

## Executive Summary

**What We're Building**: A prepaid balance system where advertisers load funds upfront and we deduct costs when campaigns are sent.

**Why This Is Better Than Subscriptions**:
- ✅ Simpler to build and maintain
- ✅ No complex plan tiers or limits initially
- ✅ Pay-as-you-go feels fairer to customers
- ✅ No subscription cancellation headaches
- ✅ Cash flow positive (money upfront)
- ✅ Easy to add subscription plans later

**Business Model**:
- Platform access: **FREE** (all features available)
- Print & Postage: **Pay per send** (deducted from balance)
- Pricing: **$1.10/postcard** (covers Lob's ~$1.05 + 5% markup)

---

## Current State Analysis

### ✅ What's Already Working

1. **Cost Tracking** - Campaigns already calculate costs:
   ```ruby
   campaign.estimated_cost_cents  # Calculated before send
   campaign.actual_cost_cents     # Real cost from Lob after send
   campaign_contact.actual_cost_cents  # Per-postcard cost
   ```

2. **Send Flow** - `SendCampaignJob` handles all sending:
   - Loops through contacts
   - Creates postcards via Lob
   - Tracks successes/failures
   - Updates total costs

3. **Cost Display** - UI already shows costs:
   - Campaign index page
   - Campaign review tab
   - Send confirmation

### ❌ What's Missing

1. **Balance Storage** - No place to store prepaid funds
2. **Payment Processing** - No way to accept payments
3. **Balance Checks** - Nothing prevents sending without funds
4. **Transaction History** - No record of deposits/charges
5. **Admin Visibility** - Platform admin can't see balances
6. **Payment Methods** - Can't store cards for easy top-ups

---

## Technical Architecture

### Database Schema

#### 1. Add Balance Fields to `advertisers` Table

```ruby
# Migration
add_column :advertisers, :balance_cents, :integer, default: 0, null: false
add_column :advertisers, :stripe_customer_id, :string
add_column :advertisers, :payment_method_last4, :string
add_column :advertisers, :payment_method_brand, :string
add_column :advertisers, :payment_method_exp_month, :integer
add_column :advertisers, :payment_method_exp_year, :integer

add_index :advertisers, :stripe_customer_id, unique: true
```

#### 2. Create `balance_transactions` Table

```ruby
create_table :balance_transactions do |t|
  t.references :advertiser, null: false, foreign_key: true
  t.string :transaction_type, null: false  # 'deposit' or 'charge'
  t.integer :amount_cents, null: false
  t.integer :balance_before_cents, null: false
  t.integer :balance_after_cents, null: false
  t.string :description, null: false
  
  # For deposits
  t.string :stripe_payment_intent_id
  t.string :stripe_charge_id
  t.string :payment_method_last4
  
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
```

#### 3. Create `payment_intents` Table (Optional - for tracking)

```ruby
create_table :payment_intents do |t|
  t.references :advertiser, null: false, foreign_key: true
  t.string :stripe_payment_intent_id, null: false
  t.integer :amount_cents, null: false
  t.string :currency, default: 'usd'
  t.string :status  # 'pending', 'succeeded', 'failed', 'canceled'
  t.string :failure_reason
  t.datetime :succeeded_at
  t.timestamps
end

add_index :payment_intents, :stripe_payment_intent_id, unique: true
add_index :payment_intents, :status
```

---

## Model Layer

### 1. Advertiser Model Enhancements

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
  
  # Transaction methods
  def add_funds!(amount_cents, stripe_payment_intent_id:, processed_by:, payment_method_last4: nil)
    raise ArgumentError, "Amount must be positive" if amount_cents <= 0
    
    transaction do
      balance_before = balance_cents
      increment!(:balance_cents, amount_cents)
      balance_after = reload.balance_cents
      
      balance_transactions.create!(
        transaction_type: 'deposit',
        amount_cents: amount_cents,
        balance_before_cents: balance_before,
        balance_after_cents: balance_after,
        description: "Funds added: #{ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)}",
        stripe_payment_intent_id: stripe_payment_intent_id,
        payment_method_last4: payment_method_last4,
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
    "#{payment_method_brand} ••••#{payment_method_last4} (exp #{payment_method_exp_month}/#{payment_method_exp_year})"
  end
  
  def payment_method_on_file?
    stripe_customer_id.present? && payment_method_last4.present?
  end
end
```

### 2. BalanceTransaction Model

```ruby
# app/models/balance_transaction.rb
class BalanceTransaction < ApplicationRecord
  belongs_to :advertiser
  belongs_to :campaign, optional: true
  belongs_to :processed_by, class_name: 'User', optional: true
  
  validates :transaction_type, presence: true, inclusion: { in: %w[deposit charge] }
  validates :amount_cents, presence: true
  validates :description, presence: true
  
  scope :deposits, -> { where(transaction_type: 'deposit') }
  scope :charges, -> { where(transaction_type: 'charge') }
  scope :recent, -> { order(created_at: :desc) }
  
  def amount_dollars
    amount_cents.abs / 100.0
  end
  
  def deposit?
    transaction_type == 'deposit'
  end
  
  def charge?
    transaction_type == 'charge'
  end
  
  def balance_before_dollars
    balance_before_cents / 100.0
  end
  
  def balance_after_dollars
    balance_after_cents / 100.0
  end
end
```

### 3. Campaign Model Enhancements

```ruby
# app/models/campaign.rb
class Campaign < ApplicationRecord
  # Add validation before sending
  validate :sufficient_balance_for_send, if: :will_send?
  
  def will_send?
    status_changed? && status == 'processing'
  end
  
  def sufficient_balance_for_send
    return if advertiser.has_sufficient_balance?(estimated_cost_cents)
    
    errors.add(:base, "Insufficient balance. Current balance: #{advertiser.balance_dollars}, Required: #{estimated_cost_dollars}")
  end
  
  def charge_advertiser!(user)
    return unless completed? && actual_cost_cents > 0
    return if charged?
    
    advertiser.charge_for_campaign!(self, processed_by: user)
    update!(charged_at: Time.current)
  end
  
  def charged?
    charged_at.present?
  end
end
```

---

## Service Layer

### StripePaymentService

```ruby
# app/services/stripe_payment_service.rb
class StripePaymentService
  def initialize(advertiser)
    @advertiser = advertiser
  end
  
  def attach_payment_method(payment_method_id, user)
    # Create Stripe customer if needed
    @advertiser.create_stripe_customer!(user) unless @advertiser.stripe_customer_id
    
    # Attach payment method to customer
    payment_method = Stripe::PaymentMethod.attach(
      payment_method_id,
      { customer: @advertiser.stripe_customer_id }
    )
    
    # Set as default payment method
    Stripe::Customer.update(
      @advertiser.stripe_customer_id,
      invoice_settings: {
        default_payment_method: payment_method_id
      }
    )
    
    # Update advertiser with payment method details
    @advertiser.update!(
      payment_method_last4: payment_method.card.last4,
      payment_method_brand: payment_method.card.brand,
      payment_method_exp_month: payment_method.card.exp_month,
      payment_method_exp_year: payment_method.card.exp_year
    )
    
    payment_method
  end
  
  def charge_and_add_funds(amount_cents, payment_method_id, user)
    raise ArgumentError, "Amount must be at least $5" if amount_cents < 500
    raise ArgumentError, "Amount must be at most $10,000" if amount_cents > 1_000_000
    
    # Create Stripe customer if needed
    @advertiser.create_stripe_customer!(user) unless @advertiser.stripe_customer_id
    
    # Create payment intent
    intent = Stripe::PaymentIntent.create(
      amount: amount_cents,
      currency: 'usd',
      customer: @advertiser.stripe_customer_id,
      payment_method: payment_method_id,
      off_session: true,
      confirm: true,
      description: "Balance top-up for #{@advertiser.name}",
      metadata: {
        advertiser_id: @advertiser.id,
        advertiser_name: @advertiser.name,
        user_id: user.id,
        user_email: user.email
      }
    )
    
    # If successful, add funds to balance
    if intent.status == 'succeeded'
      @advertiser.add_funds!(
        amount_cents,
        stripe_payment_intent_id: intent.id,
        processed_by: user,
        payment_method_last4: @advertiser.payment_method_last4
      )
    end
    
    intent
  rescue Stripe::CardError => e
    # Card was declined
    raise PaymentError, e.message
  rescue Stripe::StripeError => e
    # Other Stripe errors
    raise PaymentError, "Payment failed: #{e.message}"
  end
  
  class PaymentError < StandardError; end
end
```

---

## Controller Layer

### 1. BillingController

```ruby
# app/controllers/billing_controller.rb
class BillingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :require_admin_access
  layout 'sidebar'
  
  def index
    @balance = @advertiser.balance_dollars
    @transactions = @advertiser.balance_transactions.recent.page(params[:page]).per(50)
    @has_payment_method = @advertiser.payment_method_on_file?
  end
  
  def new_deposit
    # Show form to add funds
  end
  
  def create_deposit
    amount_dollars = params[:amount].to_f
    amount_cents = (amount_dollars * 100).to_i
    
    if amount_cents < 500
      flash[:error] = "Minimum deposit is $5.00"
      return render :new_deposit, status: :unprocessable_entity
    end
    
    if amount_cents > 1_000_000
      flash[:error] = "Maximum deposit is $10,000.00"
      return render :new_deposit, status: :unprocessable_entity
    end
    
    begin
      service = StripePaymentService.new(@advertiser)
      intent = service.charge_and_add_funds(
        amount_cents,
        params[:payment_method_id],
        current_user
      )
      
      flash[:notice] = "Successfully added #{ActionController::Base.helpers.number_to_currency(amount_dollars)} to your balance"
      redirect_to billing_path(@advertiser.slug)
    rescue StripePaymentService::PaymentError => e
      flash[:error] = e.message
      render :new_deposit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_advertiser
    @advertiser = find_advertiser_by_slug(params[:advertiser_slug])
    unless @advertiser
      redirect_to advertisers_path, alert: 'Advertiser not found'
    end
    set_current_advertiser(@advertiser)
  end
  
  def require_admin_access
    unless current_user.admin_of?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), 
                  alert: 'Only owners and admins can manage billing'
    end
  end
end
```

### 2. PaymentMethodsController

```ruby
# app/controllers/payment_methods_controller.rb
class PaymentMethodsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :require_admin_access
  layout 'sidebar'
  
  def edit
    # Show form to add/update payment method
    setup_stripe_intent
  end
  
  def update
    begin
      service = StripePaymentService.new(@advertiser)
      service.attach_payment_method(params[:payment_method_id], current_user)
      
      flash[:notice] = "Payment method updated successfully"
      redirect_to billing_path(@advertiser.slug)
    rescue Stripe::StripeError => e
      flash[:error] = "Failed to update payment method: #{e.message}"
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_advertiser
    @advertiser = find_advertiser_by_slug(params[:advertiser_slug])
    unless @advertiser
      redirect_to advertisers_path, alert: 'Advertiser not found'
    end
    set_current_advertiser(@advertiser)
  end
  
  def require_admin_access
    unless current_user.admin_of?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), 
                  alert: 'Only owners and admins can manage payment methods'
    end
  end
  
  def setup_stripe_intent
    # Create setup intent for collecting payment method without charging
    @advertiser.create_stripe_customer!(current_user) unless @advertiser.stripe_customer_id
    
    @setup_intent = Stripe::SetupIntent.create(
      customer: @advertiser.stripe_customer_id,
      metadata: {
        advertiser_id: @advertiser.id
      }
    )
  end
end
```

### 3. Webhooks::StripeController

```ruby
# app/controllers/webhooks/stripe_controller.rb
module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    def create
      payload = request.body.read
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)
      
      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
      rescue JSON::ParserError
        return head :bad_request
      rescue Stripe::SignatureVerificationError
        return head :bad_request
      end
      
      # Handle the event
      case event.type
      when 'payment_intent.succeeded'
        handle_payment_succeeded(event.data.object)
      when 'payment_intent.payment_failed'
        handle_payment_failed(event.data.object)
      when 'customer.source.updated'
        handle_payment_method_updated(event.data.object)
      end
      
      head :ok
    end
    
    private
    
    def handle_payment_succeeded(payment_intent)
      Rails.logger.info "Payment succeeded: #{payment_intent.id}"
      # Already handled in controller, but log for confirmation
    end
    
    def handle_payment_failed(payment_intent)
      Rails.logger.error "Payment failed: #{payment_intent.id} - #{payment_intent.last_payment_error&.message}"
      # Could send notification to advertiser
    end
    
    def handle_payment_method_updated(source)
      # Update payment method details if needed
      Rails.logger.info "Payment method updated for customer: #{source.customer}"
    end
  end
end
```

---

## Job Modifications

### Update SendCampaignJob

```ruby
# app/jobs/send_campaign_job.rb
class SendCampaignJob < ApplicationJob
  queue_as :default
  
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    advertiser = campaign.advertiser
    
    # PRE-FLIGHT CHECK: Verify sufficient balance
    unless advertiser.has_sufficient_balance?(campaign.estimated_cost_cents)
      campaign.update!(
        status: :failed,
        failed_at: Time.current
      )
      
      CampaignMailer.campaign_failed(
        campaign,
        "Insufficient balance. Current: #{advertiser.balance_dollars}, Required: #{campaign.estimated_cost_dollars}"
      ).deliver_later
      
      return
    end
    
    Rails.logger.info "Starting send for campaign #{campaign.id} (#{campaign.name})"
    Rails.logger.info "Advertiser balance before: $#{advertiser.balance_dollars}"
    
    # ... existing send logic ...
    
    # AFTER SEND: Charge the advertiser
    if campaign.completed? || campaign.completed_with_errors?
      begin
        # Find who initiated the send
        user = campaign.created_by_user || advertiser.users.first
        campaign.charge_advertiser!(user)
        
        Rails.logger.info "Charged advertiser $#{campaign.actual_cost_dollars} for campaign #{campaign.id}"
        Rails.logger.info "Advertiser balance after: $#{advertiser.reload.balance_dollars}"
      rescue => e
        Rails.logger.error "Failed to charge advertiser for campaign #{campaign.id}: #{e.message}"
        # Don't fail the whole campaign, but notify admins
      end
    end
    
  rescue => e
    campaign.update!(status: :failed)
    Rails.logger.error "Campaign #{campaign_id} failed: #{e.message}"
    CampaignMailer.campaign_failed(campaign, e.message).deliver_later
    raise
  end
end
```

---

## Routes

```ruby
# config/routes.rb
scope 'advertisers/:advertiser_slug' do
  # Billing routes
  get 'billing', to: 'billing#index', as: :billing
  get 'billing/add-funds', to: 'billing#new_deposit', as: :new_deposit
  post 'billing/add-funds', to: 'billing#create_deposit', as: :create_deposit
  
  # Payment methods
  get 'billing/payment-method', to: 'payment_methods#edit', as: :edit_payment_method
  patch 'billing/payment-method', to: 'payment_methods#update', as: :update_payment_method
end

# Stripe webhooks
post '/webhooks/stripe', to: 'webhooks/stripe#create'
```

---

## Views

### billing/index.html.erb

```erb
<!-- Balance Card -->
<div class="bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-lg shadow-lg p-8 text-white mb-6">
  <div class="flex items-center justify-between">
    <div>
      <p class="text-indigo-100 text-sm font-medium mb-2">Current Balance</p>
      <p class="text-5xl font-bold"><%= number_to_currency(@balance) %></p>
      <p class="text-indigo-100 text-sm mt-2">
        <% if @has_payment_method %>
          <%= @advertiser.payment_method_summary %>
        <% else %>
          No payment method on file
        <% end %>
      </p>
    </div>
    <div class="space-y-3">
      <%= link_to "Add Funds", new_deposit_path(@advertiser.slug), 
          class: "block px-6 py-3 bg-white text-indigo-600 rounded-lg font-semibold hover:bg-indigo-50 transition-colors text-center" %>
      <%= link_to "Update Payment Method", edit_payment_method_path(@advertiser.slug),
          class: "block px-6 py-3 bg-indigo-400 text-white rounded-lg font-semibold hover:bg-indigo-500 transition-colors text-center" %>
    </div>
  </div>
</div>

<!-- Transaction History -->
<div class="bg-white shadow rounded-lg">
  <div class="px-6 py-5 border-b border-gray-200">
    <h3 class="text-lg font-medium text-gray-900">Transaction History</h3>
  </div>
  
  <% if @transactions.any? %>
    <table class="min-w-full divide-y divide-gray-200">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
          <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
          <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Balance</th>
        </tr>
      </thead>
      <tbody class="bg-white divide-y divide-gray-200">
        <% @transactions.each do |txn| %>
          <tr>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              <%= txn.created_at.strftime('%b %d, %Y %I:%M%p') %>
            </td>
            <td class="px-6 py-4 text-sm text-gray-900">
              <%= txn.description %>
              <% if txn.campaign %>
                <%= link_to "(View)", campaign_path(@advertiser.slug, txn.campaign), class: "text-indigo-600 hover:text-indigo-900 ml-2" %>
              <% end %>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-right font-medium <%= txn.deposit? ? 'text-green-600' : 'text-red-600' %>">
              <%= txn.deposit? ? '+' : '' %><%= number_to_currency(txn.amount_dollars) %>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-right text-gray-500">
              <%= number_to_currency(txn.balance_after_dollars) %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    
    <%= paginate @transactions %>
  <% else %>
    <div class="px-6 py-12 text-center">
      <p class="text-gray-500">No transactions yet</p>
    </div>
  <% end %>
</div>
```

### billing/new_deposit.html.erb

```erb
<div class="max-w-2xl mx-auto">
  <h2 class="text-2xl font-bold text-gray-900 mb-6">Add Funds</h2>
  
  <div class="bg-white shadow rounded-lg p-6">
    <%= form_with url: create_deposit_path(@advertiser.slug), method: :post, id: 'payment-form' do |f| %>
      <!-- Amount -->
      <div class="mb-6">
        <%= label_tag :amount, "Amount to Add", class: "block text-sm font-medium text-gray-700 mb-2" %>
        <div class="relative rounded-md shadow-sm">
          <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <span class="text-gray-500 sm:text-sm">$</span>
          </div>
          <%= number_field_tag :amount, 100, min: 5, max: 10000, step: 1, 
              class: "pl-7 block w-full rounded-md border-gray-300 focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm",
              required: true %>
        </div>
        <p class="mt-2 text-sm text-gray-500">Minimum: $5.00, Maximum: $10,000.00</p>
      </div>
      
      <!-- Stripe Card Element -->
      <div class="mb-6">
        <%= label_tag :card_element, "Payment Method", class: "block text-sm font-medium text-gray-700 mb-2" %>
        <div id="card-element" class="p-3 border border-gray-300 rounded-md"></div>
        <div id="card-errors" class="mt-2 text-sm text-red-600"></div>
      </div>
      
      <!-- Hidden field for payment method ID -->
      <%= hidden_field_tag :payment_method_id, '', id: 'payment-method-id' %>
      
      <!-- Submit -->
      <%= button_tag type: 'submit', 
          class: "w-full inline-flex justify-center items-center px-4 py-3 border border-transparent shadow-sm text-base font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500" do %>
        <span id="button-text">Add Funds</span>
        <span id="spinner" class="hidden ml-2">Processing...</span>
      <% end %>
    <% end %>
  </div>
</div>

<script src="https://js.stripe.com/v3/"></script>
<script>
  const stripe = Stripe('<%= Rails.application.credentials.dig(:stripe, :publishable_key) %>');
  const elements = stripe.elements();
  const cardElement = elements.create('card');
  cardElement.mount('#card-element');
  
  const form = document.getElementById('payment-form');
  const submitButton = form.querySelector('button[type="submit"]');
  const buttonText = document.getElementById('button-text');
  const spinner = document.getElementById('spinner');
  
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    
    // Disable submit button
    submitButton.disabled = true;
    buttonText.classList.add('hidden');
    spinner.classList.remove('hidden');
    
    // Create payment method
    const { error, paymentMethod } = await stripe.createPaymentMethod({
      type: 'card',
      card: cardElement,
    });
    
    if (error) {
      document.getElementById('card-errors').textContent = error.message;
      submitButton.disabled = false;
      buttonText.classList.remove('hidden');
      spinner.classList.add('hidden');
    } else {
      document.getElementById('payment-method-id').value = paymentMethod.id;
      form.submit();
    }
  });
</script>
```

---

## Platform Admin Enhancements

### Platform Admin Dashboard - Add Balance Column

```ruby
# app/controllers/platform/admin/advertisers_controller.rb
def index
  @advertisers = Advertiser.select('advertisers.*, balance_cents')
                          .order(created_at: :desc)
                          .page(params[:page]).per(25)
end
```

```erb
<!-- Add to advertisers table -->
<th>Balance</th>
...
<td><%= number_to_currency(advertiser.balance_dollars) %></td>
```

---

## Configuration

### Stripe Setup

```yaml
# config/credentials.yml.enc
stripe:
  secret_key: sk_test_...
  publishable_key: pk_test_...
  webhook_secret: whsec_...
```

```ruby
# config/initializers/stripe.rb
Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
```

### Gemfile

```ruby
gem 'stripe', '~> 10.0'
```

---

## Testing Checklist

### Manual Testing Flow

1. **Add Payment Method**
   - Go to Billing
   - Click "Update Payment Method"
   - Enter test card: 4242 4242 4242 4242
   - Verify saved successfully

2. **Add Funds**
   - Click "Add Funds"
   - Enter $100
   - Complete payment
   - Verify balance shows $100
   - Verify transaction appears in history

3. **Send Campaign (Successful)**
   - Create campaign with 10 recipients
   - Estimated cost: $11.00
   - Click "Send Now"
   - Wait for completion
   - Verify balance reduced to ~$89
   - Verify charge transaction appears

4. **Send Campaign (Insufficient Balance)**
   - Reduce balance to $5
   - Try to send campaign for $11
   - Verify prevented with error message

5. **Platform Admin View**
   - Log in as platform admin
   - View advertisers list
   - Verify balance column shows correctly
   - Click into advertiser
   - Verify payment method status visible

### Stripe Test Cards

```
Success: 4242 4242 4242 4242
Decline: 4000 0000 0000 0002
Insufficient Funds: 4000 0000 0000 9995
```

---

## Rollout Plan

### Phase 1: Core Infrastructure (Day 1-2)
- [ ] Database migrations
- [ ] Model updates
- [ ] StripePaymentService
- [ ] Basic controllers
- [ ] Gem installation & config

### Phase 2: UI & Flow (Day 2-3)
- [ ] Billing index page
- [ ] Add funds page
- [ ] Payment method page
- [ ] Navigation updates
- [ ] Stripe.js integration

### Phase 3: Campaign Integration (Day 3)
- [ ] Update SendCampaignJob
- [ ] Add balance checks
- [ ] Automatic charging
- [ ] Error handling

### Phase 4: Platform Admin (Day 3)
- [ ] Balance column in advertisers list
- [ ] Payment method status indicator
- [ ] Transaction history view

### Phase 5: Testing & Polish (Day 4)
- [ ] Manual testing all flows
- [ ] Error handling improvements
- [ ] UI polish
- [ ] Documentation

---

## Future Enhancements

### Short Term (Week 2-3)
- [ ] Email receipts for deposits
- [ ] Low balance warnings
- [ ] Auto-recharge feature
- [ ] Invoice generation (PDF)
- [ ] Refunds (manual for now)

### Medium Term (Month 2)
- [ ] Subscription plans (optional)
- [ ] Volume discounts
- [ ] Agency billing (separate balances)
- [ ] Billing analytics dashboard
- [ ] Export transaction history

### Long Term (Month 3+)
- [ ] ACH/bank transfers
- [ ] International payments
- [ ] Multi-currency
- [ ] Tax handling (sales tax, VAT)
- [ ] Advanced reporting

---

## Security Considerations

1. **PCI Compliance**: Using Stripe.js means card data never touches our servers ✅
2. **Webhook Verification**: Always verify Stripe webhook signatures ✅
3. **Balance Integrity**: Use database transactions for all balance changes ✅
4. **Admin Access**: Only owners/admins can manage billing ✅
5. **Audit Trail**: Every transaction logged with user who processed it ✅
6. **Amount Limits**: Min $5, Max $10,000 per deposit ✅

---

## Cost Analysis

**Stripe Fees**: 2.9% + $0.30 per transaction

| Deposit Amount | Stripe Fee | Customer Pays |
|----------------|------------|---------------|
| $50 | $1.75 | $50.00 |
| $100 | $3.20 | $100.00 |
| $500 | $14.80 | $500.00 |

**Options**:
1. **Absorb fees**: Simpler, but costs us
2. **Pass fees to customer**: Add 3% to deposits
3. **Minimum deposit**: Encourage larger deposits

**Recommendation**: Start by absorbing fees, add option to pass through later.

---

## Questions to Answer Before Building

1. ✅ **Who can manage billing?** - Owners and admins only
2. ✅ **Minimum deposit?** - $5.00
3. ✅ **Maximum deposit?** - $10,000 (can increase later)
4. ❓ **Postcard pricing?** - $1.10/card? (Lob charges ~$1.05)
5. ❓ **Absorb or pass Stripe fees?** - Your choice
6. ❓ **Low balance warning?** - At what threshold? $10? $25?
7. ❓ **Auto-recharge?** - Add in Phase 2?
8. ❓ **Refunds?** - Manual process for now?

---

**Ready to start building?** Let me know your answers to the questions and we can begin!

