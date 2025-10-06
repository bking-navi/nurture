class Contact < ApplicationRecord
  belongs_to :advertiser
  belongs_to :source, polymorphic: true
  has_many :orders, dependent: :nullify
  has_many :campaign_contacts, dependent: :nullify

  # Enums
  enum :state, {
    enabled: 0,
    disabled: 1,
    invited: 2,
    declined: 3
  }

  # Validations
  validates :advertiser_id, presence: true
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: [:source_type, :source_id] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :email_or_phone_present

  # Scopes
  scope :from_shopify, -> { where(source_type: 'ShopifyStore') }
  scope :marketable, -> { where(accepts_marketing: true).where.not(email: nil) }
  scope :by_location, ->(city: nil, state: nil, zip: nil) {
    query = all
    if city.present?
      query = query.where("default_address->>'city' ILIKE ?", city)
    end
    if state.present?
      query = query.where("default_address->>'province_code' = ? OR default_address->>'state' = ?", state.upcase, state.upcase)
    end
    if zip.present?
      query = query.where("default_address->>'zip' = ?", zip)
    end
    query
  }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
  scope :spent_more_than, ->(amount) { where("total_spent >= ?", amount) }
  
  # RFM Scopes
  scope :rfm_recency, ->(score) { where(rfm_recency_score: score) }
  scope :rfm_frequency, ->(score) { where(rfm_frequency_score: score) }
  scope :rfm_monetary, ->(score) { where(rfm_monetary_score: score) }
  scope :rfm_segment, ->(segment) { where(rfm_segment: segment) }
  scope :high_value, -> { where("rfm_monetary_score >= ?", 4) }
  scope :recent_buyers, -> { where("rfm_recency_score >= ?", 4) }
  scope :frequent_buyers, -> { where("rfm_frequency_score >= ?", 4) }

  # Instance methods
  def display_name
    if first_name.present? || last_name.present?
      "#{first_name} #{last_name}".strip
    else
      email
    end
  end

  def full_name
    "#{first_name} #{last_name}".strip.presence || 'Unknown'
  end

  def from_shopify?
    source_type == 'ShopifyStore'
  end

  def marketable?
    accepts_marketing && email.present?
  end

  def shopify_url
    return unless from_shopify?
    "#{source.shopify_admin_url}/customers/#{external_id}"
  end

  def primary_address
    default_address || addresses&.first
  end

  # RFM Calculations
  def days_since_last_order
    return nil unless last_order_at
    (Time.current - last_order_at).to_i / 1.day
  end

  def calculate_rfm_scores!
    # Calculate scores based on advertiser-wide percentiles
    contacts = advertiser.contacts.where.not(last_order_at: nil)
    
    # Recency: Lower days = higher score (5 is best)
    recency_percentiles = calculate_percentiles(contacts, 'last_order_at', reverse: true)
    self.rfm_recency_score = score_from_percentile(days_since_last_order, recency_percentiles, reverse: true)
    
    # Frequency: More orders = higher score
    frequency_percentiles = calculate_percentiles(contacts, 'orders_count')
    self.rfm_frequency_score = score_from_percentile(orders_count, frequency_percentiles)
    
    # Monetary: More spent = higher score
    monetary_percentiles = calculate_percentiles(contacts, 'total_spent')
    self.rfm_monetary_score = score_from_percentile(total_spent.to_f, monetary_percentiles)
    
    # Calculate average order value
    self.average_order_value = orders_count > 0 ? (total_spent / orders_count) : 0
    
    # Assign RFM segment
    self.rfm_segment = determine_rfm_segment
    
    save
  end

  def determine_rfm_segment
    # Standard RFM segmentation
    r = rfm_recency_score
    f = rfm_frequency_score
    m = rfm_monetary_score
    
    return "Champions" if r >= 4 && f >= 4 && m >= 4
    return "Loyal Customers" if r >= 3 && f >= 4 && m >= 3
    return "Potential Loyalist" if r >= 4 && f.between?(2, 3) && m >= 3
    return "Recent Customers" if r >= 4 && f <= 2 && m >= 2
    return "Promising" if r >= 3 && f <= 2 && m <= 2
    return "Needs Attention" if r.between?(2, 3) && f.between?(2, 3) && m.between?(2, 3)
    return "About to Sleep" if r.between?(2, 3) && f <= 2 && m <= 2
    return "At Risk" if r <= 2 && f.between?(2, 4) && m.between?(2, 4)
    return "Cannot Lose Them" if r <= 2 && f >= 4 && m >= 4
    return "Hibernating" if r <= 2 && f <= 2 && m >= 2
    return "Lost" if r <= 2 && f <= 2 && m <= 2
    
    "Unknown"
  end

  # Class method to update RFM for all contacts in an advertiser
  def self.update_rfm_scores_for_advertiser(advertiser)
    contacts = advertiser.contacts.where.not(last_order_at: nil)
    contacts.find_each do |contact|
      contact.calculate_rfm_scores!
    end
  end

  private

  def email_or_phone_present
    if email.blank? && phone.blank?
      errors.add(:base, "Either email or phone must be present")
    end
  end

  def calculate_percentiles(contacts, field, reverse: false)
    values = if field == 'last_order_at' && reverse
      # For recency, calculate days since last order
      contacts.pluck(:last_order_at).compact.map { |date| (Time.current - date).to_i / 1.day }
    else
      contacts.pluck(field).compact
    end
    
    return [0, 0, 0, 0, 0] if values.empty?
    
    sorted = values.sort
    [
      sorted[0],
      sorted[(sorted.length * 0.2).to_i],
      sorted[(sorted.length * 0.4).to_i],
      sorted[(sorted.length * 0.6).to_i],
      sorted[(sorted.length * 0.8).to_i]
    ]
  end

  def score_from_percentile(value, percentiles, reverse: false)
    return 0 if value.nil? || percentiles.all?(0)
    
    score = case value
    when 0..percentiles[1] then 1
    when percentiles[1]..percentiles[2] then 2
    when percentiles[2]..percentiles[3] then 3
    when percentiles[3]..percentiles[4] then 4
    else 5
    end
    
    reverse ? (6 - score) : score
  end
end

