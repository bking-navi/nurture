class Advertiser < ApplicationRecord
  # Associations
  has_many :advertiser_memberships, dependent: :destroy
  has_many :users, through: :advertiser_memberships
  has_many :invitations, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :color_palettes, dependent: :destroy
  
  # Shopify integration
  has_many :shopify_stores, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :sync_jobs, dependent: :destroy
  has_many :segments, dependent: :destroy
  has_many :creatives, dependent: :destroy
  has_many :suppression_list_entries, dependent: :destroy
  
  # Agency relationships
  has_many :advertiser_agency_accesses, dependent: :destroy
  has_many :agencies, through: :advertiser_agency_accesses
  
  # Billing
  has_many :balance_transactions, dependent: :restrict_with_error

  # Serialize settings as JSON for SQLite (PostgreSQL will use jsonb)
  serialize :settings, coder: JSON

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :street_address, presence: true
  validates :city, presence: true
  validates :state, presence: true, format: { with: /\A[A-Z]{2}\z/, message: "must be 2-letter state code (e.g., CA, NY, TX)" }
  validates :postal_code, presence: true
  validates :country, presence: true
  validates :website_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }
  
  # Normalize state to uppercase before validation
  before_validation :normalize_state

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  after_initialize :set_default_settings, if: :new_record?

  # Scopes
  scope :active, -> { joins(:advertiser_memberships).where(advertiser_memberships: { status: 'accepted' }).distinct }

  # Instance methods
  def owner
    users.joins(:advertiser_memberships)
         .where(advertiser_memberships: { advertiser_id: id, role: 'owner' })
         .first
  end

  def address_formatted
    [
      street_address,
      "#{city}, #{state} #{postal_code}",
      country
    ].join("\n")
  end
  
  # =================
  # BILLING METHODS
  # =================
  
  # Balance management
  def balance_dollars
    balance_cents / 100.0
  end
  
  def pending_balance_dollars
    pending_balance_cents / 100.0
  end
  
  def total_balance_cents
    balance_cents + pending_balance_cents
  end
  
  def total_balance_dollars
    total_balance_cents / 100.0
  end
  
  def has_pending_balance?
    pending_balance_cents > 0
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
  def add_funds!(amount_cents, stripe_payment_intent_id:, processed_by:, payment_method_last4: nil, stripe_fee_cents: nil, auto_recharge: false, payment_method_type: 'card', status: 'completed')
    raise ArgumentError, "Amount must be positive" if amount_cents <= 0
    
    transaction do
      # For pending ACH payments, add to pending_balance instead
      if status == 'pending'
        balance_before = balance_cents
        increment!(:pending_balance_cents, amount_cents)
        balance_after = balance_cents
      else
        balance_before = balance_cents
        increment!(:balance_cents, amount_cents)
        balance_after = reload.balance_cents
      end
      
      txn_type = auto_recharge ? 'auto_recharge' : 'deposit'
      description = if auto_recharge
        "Auto-recharge: #{ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)}"
      elsif status == 'pending'
        "Pending deposit (ACH): #{ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)}"
      else
        "Funds added: #{ActionController::Base.helpers.number_to_currency(amount_cents / 100.0)}"
      end
      
      balance_transactions.create!(
        transaction_type: txn_type,
        amount_cents: amount_cents,
        balance_before_cents: balance_before,
        balance_after_cents: balance_after,
        description: description,
        stripe_payment_intent_id: stripe_payment_intent_id,
        payment_method_last4: payment_method_last4,
        stripe_fee_cents: stripe_fee_cents,
        processed_by: processed_by,
        payment_method_type: payment_method_type,
        status: status
      )
    end
  end
  
  # Convert pending balance to available balance (when ACH clears)
  def clear_pending_funds!(transaction)
    raise ArgumentError, "Transaction must be pending" unless transaction.pending?
    raise ArgumentError, "Transaction must be ACH" unless transaction.ach_payment?
    
    transaction do
      amount = transaction.amount_cents
      decrement!(:pending_balance_cents, amount)
      increment!(:balance_cents, amount)
      
      transaction.update!(
        status: 'completed',
        balance_after_cents: reload.balance_cents
      )
    end
  end
  
  def charge_for_campaign!(campaign, processed_by:)
    raise ArgumentError, "Campaign must have actual cost" unless campaign.actual_cost_cents&.positive?
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
      
      # Mark campaign as charged
      campaign.update!(charged_at: Time.current)
      
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
  
  # Calculate suppression impact statistics
  def suppression_impact_stats(lookback_days: 30)
    stats = {
      total_contacts: 0,
      recent_orders_count: 0,
      recent_mail_count: 0,
      suppression_list_count: 0,
      total_suppressed: 0,
      percentage_suppressed: 0
    }
    
    # Get total addressable contacts (those with valid addresses or email)
    stats[:total_contacts] = contacts.count
    
    return stats if stats[:total_contacts].zero?
    
    # Count contacts who would be suppressed by recent orders rule
    if recent_order_suppression_days > 0
      stats[:recent_orders_count] = contacts
        .where("last_order_at >= ?", recent_order_suppression_days.days.ago)
        .count
    end
    
    # Count contacts who would be suppressed by recent mail rule
    if recent_mail_suppression_days > 0
      stats[:recent_mail_count] = contacts
        .where("last_mailed_at >= ?", recent_mail_suppression_days.days.ago)
        .count
    end
    
    # Count contacts on suppression list
    if dnm_enabled
      stats[:suppression_list_count] = suppression_list_entries.count
    end
    
    # Calculate total unique suppressed contacts
    # We need to account for overlaps, so let's get unique contacts
    suppressed_contact_ids = Set.new
    
    if recent_order_suppression_days > 0
      suppressed_contact_ids.merge(
        contacts.where("last_order_at >= ?", recent_order_suppression_days.days.ago).pluck(:id)
      )
    end
    
    if recent_mail_suppression_days > 0
      suppressed_contact_ids.merge(
        contacts.where("last_mailed_at >= ?", recent_mail_suppression_days.days.ago).pluck(:id)
      )
    end
    
    if dnm_enabled
      # Find contacts whose email matches suppression list
      suppressed_emails = suppression_list_entries.where.not(email: nil).pluck(:email)
      if suppressed_emails.any?
        suppressed_contact_ids.merge(
          contacts.where(email: suppressed_emails).pluck(:id)
        )
      end
    end
    
    stats[:total_suppressed] = suppressed_contact_ids.size
    stats[:percentage_suppressed] = stats[:total_contacts] > 0 ? 
      ((stats[:total_suppressed].to_f / stats[:total_contacts]) * 100).round : 0
    
    stats
  end

  private

  def generate_slug
    base_slug = name.parameterize
    candidate_slug = base_slug
    counter = 1

    while Advertiser.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate_slug
  end

  def set_default_settings
    self.settings ||= {
      timezone: "America/New_York",
      currency: "USD",
      email_from_name: name,
      email_reply_to: ""
    }
  end
  
  def normalize_state
    self.state = state&.upcase
  end
  
  def logo_url
    # TODO: Implement logo upload with Active Storage
    # For now, return a placeholder or settings value
    settings&.dig('logo_url')
  end
end
