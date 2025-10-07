# Billing & Monetization Infrastructure

**Date**: October 7, 2025  
**Status**: NOT IMPLEMENTED (Launch Blocker!)  
**Priority**: 🔴 CRITICAL - Cannot charge customers without this  
**Effort**: 28-32 hours (Week 1-2)

---

## Executive Summary

**Current State**: We have ZERO billing infrastructure. We literally cannot charge customers or track usage.

**Critical Missing Pieces**:
1. Payment processing (Stripe)
2. Subscription management
3. Usage tracking & metering (postcards sent)
4. Plan enforcement & limits
5. Invoicing
6. Payment failure handling
7. Upgrade/downgrade flows

**Risk**: This is a **LAUNCH BLOCKER**. Without billing, we're just a free tool.

---

## What's Missing

### 1. Payment Processing (Stripe Integration) 🔴 CRITICAL

**What it does**: Accept credit cards, process payments, handle subscriptions

**Required**:
```ruby
# Gemfile
gem 'stripe'

# Database
- stripe_customer_id (advertisers table)
- stripe_subscription_id (advertisers table)
- payment_method_last4 (advertisers table)
- billing_email (advertisers table)

# Models
- BillingEvent (track all payment events)
- Invoice (generate invoices)
- PaymentMethod (store payment info)

# Controllers
- billing_controller.rb (manage subscriptions)
- payment_methods_controller.rb (update cards)
- webhooks/stripe_controller.rb (handle Stripe events)

# Views
- billing/index.html.erb (subscription overview)
- billing/plans.html.erb (choose plan)
- payment_methods/edit.html.erb (update card)
```

**Effort**: 16 hours
- Stripe account setup: 1h
- Gem integration: 2h
- Database migrations: 1h
- Models + business logic: 4h
- Controllers: 4h
- Views: 3h
- Webhook handling: 1h

---

### 2. Subscription Management 🔴 CRITICAL

**What it does**: Track which plan customer is on, when it renews, if payment failed

**Pricing Structure** (Proposed):

| Plan | Base Price | Postcards Included | Overage | Target Customer |
|------|------------|-------------------|---------|-----------------|
| **Starter** | $49/mo | 250 | $0.30/card | New stores, testing |
| **Growth** | $99/mo | 1,000 | $0.25/card | Active senders |
| **Pro** | $249/mo | 5,000 | $0.20/card | High volume |
| **Enterprise** | Custom | Custom | $0.15/card | 10K+ postcards |

**Features by Plan**:
- **All plans**: Shopify integration, RFM analysis, attribution, segments
- **Growth+**: QR code tracking, A/B testing
- **Pro+**: Identity resolution, priority support
- **Enterprise**: Custom attribution windows, dedicated success manager

**Required**:
```ruby
# Database
- plan_name (advertisers table)
- plan_amount (advertisers table)
- plan_postcards_included (advertisers table)
- plan_overage_rate (advertisers table)
- billing_period_start (advertisers table)
- billing_period_end (advertisers table)
- subscription_status (advertisers table)

# Models
class Advertiser
  enum subscription_status: {
    trial: 0,
    active: 1,
    past_due: 2,
    canceled: 3,
    paused: 4
  }
  
  def postcards_sent_this_period
    campaigns.where('sent_at >= ?', billing_period_start).sum(:recipient_count)
  end
  
  def overage_charges
    sent = postcards_sent_this_period
    included = plan_postcards_included || 0
    overage = [sent - included, 0].max
    overage * plan_overage_rate
  end
  
  def current_bill
    plan_amount + overage_charges
  end
end
```

**Effort**: 8 hours
- Database schema: 1h
- Model logic: 3h
- Plan definitions: 1h
- Subscription flows: 3h

---

### 3. Usage Tracking & Metering 🔴 CRITICAL

**What it does**: Count postcards sent, calculate overages, report to Stripe

**Required**:
```ruby
# Database
create_table :usage_records do |t|
  t.references :advertiser, null: false
  t.references :campaign, null: false
  t.integer :quantity, null: false
  t.string :unit_type, default: 'postcard'
  t.decimal :unit_price, precision: 6, scale: 2
  t.decimal :total_amount, precision: 10, scale: 2
  t.datetime :recorded_at, null: false
  t.string :stripe_usage_record_id
  t.timestamps
end

# Track every postcard send
class Campaign
  after_update :track_usage, if: :sent_count_changed?
  
  def track_usage
    return unless sent_count_changed?
    
    new_postcards = sent_count - sent_count_was
    
    UsageRecord.create!(
      advertiser: advertiser,
      campaign: self,
      quantity: new_postcards,
      unit_price: advertiser.plan_overage_rate,
      total_amount: new_postcards * advertiser.plan_overage_rate,
      recorded_at: Time.current
    )
    
    # Report to Stripe for metered billing
    StripeClient.report_usage(
      subscription_id: advertiser.stripe_subscription_id,
      quantity: new_postcards,
      timestamp: Time.current.to_i
    )
  end
end

# Monthly rollup for billing
class MonthlyUsageReport
  def self.generate(advertiser, period_start, period_end)
    {
      plan_name: advertiser.plan_name,
      plan_amount: advertiser.plan_amount,
      postcards_included: advertiser.plan_postcards_included,
      postcards_sent: advertiser.usage_records
        .where(recorded_at: period_start..period_end)
        .sum(:quantity),
      overage_count: [postcards_sent - postcards_included, 0].max,
      overage_amount: overage_count * advertiser.plan_overage_rate,
      total_amount: advertiser.plan_amount + overage_amount
    }
  end
end
```

**Effort**: 12 hours
- Database schema: 2h
- Usage tracking logic: 4h
- Stripe metered billing: 3h
- Reporting: 3h

---

### 4. Plan Enforcement & Limits 🟡 HIGH

**What it does**: Prevent customers from exceeding limits without upgrading

**Limits by Plan**:
- **Starter**: 250 postcards/month, 5 campaigns/month
- **Growth**: 1,000 postcards/month, unlimited campaigns
- **Pro**: 5,000 postcards/month, unlimited everything
- **Enterprise**: Custom limits

**Required**:
```ruby
# app/models/campaign.rb
validate :check_plan_limits, on: :create

def check_plan_limits
  # Check campaign count limit
  if advertiser.plan_name == 'starter'
    campaigns_this_month = advertiser.campaigns
      .where('created_at >= ?', advertiser.billing_period_start)
      .count
    
    if campaigns_this_month >= 5
      errors.add(:base, "Starter plan limited to 5 campaigns/month. Upgrade to Growth for unlimited campaigns.")
    end
  end
  
  # Check postcard limit
  if advertiser.postcards_remaining_this_period < recipient_count
    remaining = advertiser.postcards_remaining_this_period
    needed = recipient_count - remaining
    overage_cost = needed * advertiser.plan_overage_rate
    
    errors.add(:base, "This campaign will send #{needed} postcards over your plan limit, adding $#{overage_cost} to your next bill. Continue?")
  end
end

# app/models/advertiser.rb
def postcards_remaining_this_period
  included = plan_postcards_included || 0
  sent = postcards_sent_this_period
  [included - sent, 0].max
end

def can_send_campaign?(postcard_count)
  # Allow if they have enough in plan
  return true if postcards_remaining_this_period >= postcard_count
  
  # Allow if subscription is active (will charge overage)
  return true if subscription_status == 'active'
  
  # Block if no active subscription
  false
end
```

**Effort**: 4 hours
- Limit checking: 2h
- Error messages: 1h
- Upgrade prompts: 1h

---

### 5. Invoicing 🟡 MEDIUM

**What it does**: Generate invoices for customers, send via email

**Required**:
```ruby
# Database
create_table :invoices do |t|
  t.references :advertiser, null: false
  t.string :stripe_invoice_id
  t.string :invoice_number
  t.date :period_start
  t.date :period_end
  t.decimal :subtotal, precision: 10, scale: 2
  t.decimal :tax, precision: 10, scale: 2
  t.decimal :total, precision: 10, scale: 2
  t.string :status # draft, open, paid, void
  t.datetime :paid_at
  t.jsonb :line_items, default: []
  t.timestamps
end

# Generate invoice at end of billing period
class Invoice < ApplicationRecord
  def self.generate_for_period(advertiser)
    usage = MonthlyUsageReport.generate(
      advertiser,
      advertiser.billing_period_start,
      advertiser.billing_period_end
    )
    
    invoice = create!(
      advertiser: advertiser,
      invoice_number: next_invoice_number,
      period_start: advertiser.billing_period_start,
      period_end: advertiser.billing_period_end,
      line_items: [
        {
          description: "#{advertiser.plan_name} Plan",
          quantity: 1,
          unit_price: advertiser.plan_amount,
          amount: advertiser.plan_amount
        },
        {
          description: "Postcard Overage (#{usage[:overage_count]} × $#{advertiser.plan_overage_rate})",
          quantity: usage[:overage_count],
          unit_price: advertiser.plan_overage_rate,
          amount: usage[:overage_amount]
        }
      ],
      subtotal: usage[:total_amount],
      total: usage[:total_amount],
      status: 'draft'
    )
    
    # Create in Stripe
    stripe_invoice = Stripe::Invoice.create({
      customer: advertiser.stripe_customer_id,
      subscription: advertiser.stripe_subscription_id,
      auto_advance: true
    })
    
    invoice.update!(stripe_invoice_id: stripe_invoice.id)
    invoice
  end
end
```

**Effort**: 6 hours
- Database schema: 1h
- Invoice generation: 3h
- Email templates: 1h
- PDF generation: 1h

---

### 6. Payment Failure Handling 🟡 HIGH

**What it does**: Handle declined cards, retry payments, pause accounts

**Flow**:
```
1. Payment fails (card declined)
2. Update subscription_status to 'past_due'
3. Email customer immediately
4. Retry payment after 3 days
5. If still failed, retry after 7 days
6. If still failed, pause account (can't send campaigns)
7. After 30 days, cancel subscription
```

**Required**:
```ruby
# Stripe webhook handler
# app/controllers/webhooks/stripe_controller.rb
class Webhooks::StripeController < ApplicationController
  def payment_failed
    event = Stripe::Event.construct_from(params[:data])
    invoice = event.data.object
    
    advertiser = Advertiser.find_by(stripe_customer_id: invoice.customer)
    return head :not_found unless advertiser
    
    advertiser.update!(
      subscription_status: :past_due,
      payment_failed_at: Time.current
    )
    
    # Send immediate notification
    BillingMailer.payment_failed(advertiser).deliver_later
    
    # Schedule retries
    RetryPaymentJob.set(wait: 3.days).perform_later(advertiser.id)
  end
  
  def payment_succeeded
    # ... handle successful payment
    advertiser.update!(
      subscription_status: :active,
      payment_failed_at: nil
    )
  end
end

# Prevent actions when past due
class ApplicationController
  def check_billing_status
    if Current.advertiser&.subscription_status == 'past_due'
      redirect_to billing_path, alert: 'Your payment method failed. Please update your card to continue.'
    end
  end
end
```

**Effort**: 6 hours
- Webhook handlers: 2h
- Retry logic: 2h
- Account pausing: 1h
- Email notifications: 1h

---

### 7. Upgrade/Downgrade Flows 🟡 MEDIUM

**What it does**: Let customers change plans, prorate charges

**Scenarios**:

**Upgrade (Starter → Growth)**:
- Immediate access to new features
- Prorate: Charge difference for remaining period
- Example: $50 unused from Starter → Credit $50, charge $99, net: $49

**Downgrade (Growth → Starter)**:
- Takes effect at next billing period (no refund)
- Warning: "Your downgrade will take effect on [date]. Current features remain active until then."

**Required**:
```ruby
# app/controllers/billing_controller.rb
def change_plan
  new_plan = params[:plan_name]
  
  if upgrading?(new_plan)
    # Immediate upgrade with proration
    stripe_subscription = Stripe::Subscription.update(
      advertiser.stripe_subscription_id,
      items: [{
        id: advertiser.stripe_subscription_item_id,
        price: Plan.find(new_plan).stripe_price_id
      }],
      proration_behavior: 'create_prorations'
    )
    
    advertiser.update!(
      plan_name: new_plan,
      # ... update plan details
    )
    
    redirect_to billing_path, notice: "Upgraded to #{new_plan} plan!"
  else
    # Schedule downgrade for next period
    Stripe::Subscription.update(
      advertiser.stripe_subscription_id,
      items: [{
        id: advertiser.stripe_subscription_item_id,
        price: Plan.find(new_plan).stripe_price_id
      }],
      proration_behavior: 'none',
      billing_cycle_anchor: 'unchanged'
    )
    
    advertiser.update!(pending_plan_change: new_plan)
    
    redirect_to billing_path, notice: "Your plan will change to #{new_plan} on #{advertiser.billing_period_end.strftime('%B %d')}."
  end
end
```

**Effort**: 4 hours
- Upgrade logic: 2h
- Downgrade logic: 1h
- UI flows: 1h

---

## Additional Billing Features (Nice-to-Have)

### 8. Free Trial 🟢 LOW PRIORITY

**What it does**: 14-day free trial, no credit card required

**Required**:
```ruby
# app/models/advertiser.rb
after_create :start_trial

def start_trial
  update!(
    subscription_status: :trial,
    trial_ends_at: 14.days.from_now
  )
end

def trial_active?
  subscription_status == 'trial' && trial_ends_at > Time.current
end

def trial_ended?
  subscription_status == 'trial' && trial_ends_at <= Time.current
end

# Block actions after trial expires
def can_send_campaigns?
  return true if subscription_status == 'active'
  return true if trial_active?
  false
end
```

**Effort**: 3 hours

---

### 9. Annual Billing (Save 20%) 🟢 LOW PRIORITY

**What it does**: Offer annual plans with discount

**Pricing**:
- **Starter**: $49/mo or $470/year (save $118)
- **Growth**: $99/mo or $950/year (save $238)
- **Pro**: $249/mo or $2,390/year (save $598)

**Effort**: 2 hours (just add new Stripe prices)

---

### 10. Referral Credits 🟢 LOW PRIORITY

**What it does**: Give $25 credit for referring a customer

**Effort**: 8 hours

---

### 11. Coupon Codes 🟢 LOW PRIORITY

**What it does**: Apply discounts (e.g., "LAUNCH50" for 50% off first month)

**Effort**: 4 hours

---

## Implementation Priority

### **Week 1: Launch Blockers** (20 hours)
1. Stripe integration: 16h
2. Basic subscription management: 4h

**Result**: Can charge customers

---

### **Week 2: Essential Operations** (12 hours)
1. Usage tracking & metering: 8h
2. Plan enforcement: 4h

**Result**: Can track usage, prevent abuse

---

### **Week 3: Professional Polish** (16 hours)
1. Invoicing: 6h
2. Payment failure handling: 6h
3. Upgrade/downgrade flows: 4h

**Result**: Professional billing experience

---

### **Later: Nice-to-Haves** (17 hours)
1. Free trial: 3h
2. Annual billing: 2h
3. Referral program: 8h
4. Coupon codes: 4h

**Result**: Growth & retention features

---

## Total Effort

| Phase | Features | Hours | Timeline |
|-------|----------|-------|----------|
| **Phase 1** | Stripe + subscriptions | 20h | Week 1 |
| **Phase 2** | Usage + limits | 12h | Week 2 |
| **Phase 3** | Polish | 16h | Week 3 |
| **Phase 4** | Growth features | 17h | Month 2+ |
| **TOTAL** | Full billing system | **65h** | 3-4 weeks |

**Minimum to launch**: Phase 1 + Phase 2 = **32 hours** (can launch without invoicing/polish)

---

## Tech Stack Recommendations

### Payment Processing
✅ **Stripe**: Industry standard, excellent docs, Webhook support  
❌ PayPal: Clunky API, poor developer experience  
❌ Braintree: Overkill for our needs

### Gems
```ruby
gem 'stripe', '~> 10.0'           # Stripe API
gem 'pay', '~> 7.0'                # Rails billing framework (optional, adds abstraction)
gem 'receipts', '~> 2.0'           # PDF invoice generation
```

**Recommendation**: Use `stripe` gem directly (don't need Pay gem abstraction for our simple use case)

---

## Database Schema Summary

```ruby
# Add to advertisers table
add_column :advertisers, :stripe_customer_id, :string
add_column :advertisers, :stripe_subscription_id, :string
add_column :advertisers, :stripe_subscription_item_id, :string
add_column :advertisers, :plan_name, :string, default: 'growth'
add_column :advertisers, :plan_amount, :decimal, precision: 8, scale: 2
add_column :advertisers, :plan_postcards_included, :integer
add_column :advertisers, :plan_overage_rate, :decimal, precision: 6, scale: 2
add_column :advertisers, :billing_period_start, :datetime
add_column :advertisers, :billing_period_end, :datetime
add_column :advertisers, :subscription_status, :integer, default: 0
add_column :advertisers, :trial_ends_at, :datetime
add_column :advertisers, :payment_failed_at, :datetime
add_column :advertisers, :billing_email, :string

add_index :advertisers, :stripe_customer_id
add_index :advertisers, :stripe_subscription_id
add_index :advertisers, :subscription_status

# New tables
create_table :usage_records
create_table :invoices
create_table :billing_events (audit log)
```

---

## Testing Strategy

### Manual Testing Checklist
- [ ] Can create Stripe customer
- [ ] Can subscribe to plan
- [ ] Usage tracked correctly
- [ ] Overage calculated correctly
- [ ] Plan limits enforced
- [ ] Payment failure handled
- [ ] Can upgrade plan
- [ ] Can downgrade plan
- [ ] Webhooks processed correctly

### Stripe Test Mode
- Use test credit cards: `4242 4242 4242 4242`
- Trigger failures: `4000 0000 0000 0341`
- Test in Stripe dashboard: https://dashboard.stripe.com/test

---

## Customer Experience

### Onboarding Flow
```
1. Sign up → Start 14-day trial (no card required)
2. Send first campaign → See attribution results
3. Day 12 → Email: "2 days left in trial"
4. Day 14 → Prompt to add payment method
5. Add card → Subscribe to Growth plan
6. Send campaigns → Track usage → Get billed monthly
```

### Billing UI
```
/billing
  - Current plan (Growth - $99/month)
  - Usage this period (750 / 1,000 postcards)
  - Next bill: $99.00 on Oct 31
  - Payment method: •••• 4242 [Update]
  - [Upgrade to Pro] [Cancel Subscription]

/billing/plans
  - Starter ($49/mo)
  - Growth ($99/mo) ← You're here
  - Pro ($249/mo)
  - Enterprise (Contact us)

/billing/history
  - Oct 2025: $99.00 (Paid) [Invoice PDF]
  - Sep 2025: $124.00 (Paid) [Invoice PDF]
  - Aug 2025: $99.00 (Paid) [Invoice PDF]
```

---

## Risk Mitigation

### What Could Go Wrong

**Risk**: Stripe account gets banned  
**Mitigation**: Follow Stripe TOS, clear use case, good fraud prevention

**Risk**: Customer disputes charges  
**Mitigation**: Clear pricing, usage tracking, good docs

**Risk**: Webhooks fail to process  
**Mitigation**: Retry logic, monitoring, manual reconciliation

**Risk**: Underpricing (lose money per customer)  
**Mitigation**: Track unit economics, adjust pricing after beta

---

## Related Documentation

- [Attribution Tracking Spec](./ATTRIBUTION-TRACKING-SPEC.md) - How to prove ROI
- [GTM One-Pager](./GTM-ONE-PAGER.md) - Executive summary
- [Code Quality Assessment](./CODE-QUALITY-ASSESSMENT.md) - Technical foundation

---

**Bottom Line**: We need **32 hours minimum** to build billing infrastructure before we can charge customers. This is non-negotiable for launch.

**Recommendation**: Build Stripe + subscriptions (20h) in Week 1, add usage tracking (12h) in Week 2, launch with basic billing, polish later.

