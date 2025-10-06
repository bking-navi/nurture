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

  # Instance methods
  def display_name
    if first_name.present? || last_name.present?
      "#{first_name} #{last_name}".strip
    else
      email
    end
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

  private

  def email_or_phone_present
    if email.blank? && phone.blank?
      errors.add(:base, "Either email or phone must be present")
    end
  end
end

