class Agency < ApplicationRecord
  # Associations
  has_many :agency_memberships, dependent: :destroy
  has_many :users, through: :agency_memberships
  has_many :advertiser_agency_accesses, dependent: :destroy
  has_many :advertisers, through: :advertiser_agency_accesses
  has_many :agency_client_assignments, through: :agency_memberships
  has_many :agency_invitations, dependent: :destroy
  
  # Serialize settings as JSON
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
  scope :active, -> { joins(:agency_memberships).where(agency_memberships: { status: 'accepted' }).distinct }
  
  # Instance methods
  def owner
    users.joins(:agency_memberships)
         .where(agency_memberships: { agency_id: id, role: 'owner' })
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
    
    while Agency.exists?(slug: candidate_slug)
      candidate_slug = "#{base_slug}-#{counter}"
      counter += 1
    end
    
    self.slug = candidate_slug
  end
  
  def set_default_settings
    self.settings ||= {
      timezone: "America/New_York",
      currency: "USD"
    }
  end
  
  def normalize_state
    self.state = state&.upcase
  end
end
