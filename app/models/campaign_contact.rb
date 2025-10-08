class CampaignContact < ApplicationRecord
  belongs_to :campaign
  belongs_to :contact, optional: true
  
  # Serialize JSON fields for SQLite compatibility
  serialize :metadata, coder: JSON
  serialize :lob_response, coder: JSON
  
  enum :status, {
    pending: 0,
    validating: 1,
    sending: 2,
    sent: 3,
    in_transit: 4,
    delivered: 5,
    returned: 6,
    failed: 7
  }
  
  validates :first_name, :last_name, presence: true
  validates :address_line1, :address_city, :address_state, :address_zip, presence: true
  validates :address_state, format: { with: /\A[A-Z]{2}\z/, message: "must be 2-letter state code" }
  validates :address_zip, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be valid ZIP code" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  # Normalize state to uppercase before validation
  before_validation :normalize_state
  
  scope :ready_to_send, -> { where(status: :pending) }
  scope :successfully_sent, -> { where(status: [:sent, :in_transit, :delivered]) }
  scope :suppressed, -> { where(suppressed: true) }
  scope :not_suppressed, -> { where(suppressed: false) }
  scope :sendable, ->(override_suppression = false) { 
    override_suppression ? where(status: :pending) : where(status: :pending, suppressed: false) 
  }
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def address_formatted
    lines = [
      full_name,
      company,
      address_line1,
      address_line2,
      "#{address_city}, #{address_state} #{address_zip}"
    ].compact.reject(&:blank?)
    
    lines.join("\n")
  end
  
  def cost_dollars
    (actual_cost_cents || 0) / 100.0
  end
  
  def deliverable?
    !status.in?(['failed', 'returned'])
  end
  
  # Address validation with Lob
  def validate_address!
    update!(status: :validating)
    
    result = Lob::USVerification.verify(
      primary_line: address_line1,
      secondary_line: address_line2,
      city: address_city,
      state: address_state,
      zip_code: address_zip
    )
    
    if result.deliverability == 'deliverable'
      # Update with validated address
      update!(
        address_line1: result.primary_line,
        address_line2: result.secondary_line,
        address_city: result.components.city,
        address_state: result.components.state,
        address_zip: result.components.zip_code,
        status: :pending
      )
      true
    else
      update!(
        status: :failed,
        send_error: "Address not deliverable: #{result.deliverability}"
      )
      false
    end
  rescue => e
    update!(
      status: :failed,
      send_error: "Address validation failed: #{e.message}"
    )
    false
  end
  
  private
  
  def normalize_state
    self.address_state = address_state&.upcase
  end
end

