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
