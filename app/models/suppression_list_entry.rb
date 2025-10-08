class SuppressionListEntry < ApplicationRecord
  belongs_to :advertiser
  
  # Validations
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :email_or_address_present
  validate :unique_email_or_address
  
  # Normalize fields before validation
  before_validation :normalize_fields
  
  # Scopes
  scope :by_advertiser, ->(advertiser) { where(advertiser: advertiser) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Class method to check if contact is on suppression list
  # Checks by email OR address match
  def self.on_list?(advertiser, email: nil, address_line1: nil, address_city: nil, address_state: nil, address_zip: nil)
    return false if email.blank? && (address_line1.blank? || address_city.blank? || address_state.blank? || address_zip.blank?)
    
    query = where(advertiser: advertiser)
    
    # Normalize inputs
    norm_email = email.present? ? email.downcase.strip : nil
    norm_address_line1 = address_line1.present? ? normalize_address_field(address_line1) : nil
    norm_city = address_city.present? ? address_city.upcase.strip : nil
    norm_state = address_state.present? ? address_state.upcase.strip : nil
    norm_zip = address_zip.present? ? address_zip.strip : nil
    
    # Build conditions as separate where clauses combined with OR
    if norm_email.present? && norm_address_line1.present?
      # Check both email and address (OR condition)
      query.where(
        "email = ? OR (address_line1 = ? AND address_city = ? AND address_state = ? AND address_zip = ?)",
        norm_email, norm_address_line1, norm_city, norm_state, norm_zip
      ).exists?
    elsif norm_email.present?
      # Check email only
      query.where(email: norm_email).exists?
    elsif norm_address_line1.present?
      # Check address only
      query.where(
        address_line1: norm_address_line1,
        address_city: norm_city,
        address_state: norm_state,
        address_zip: norm_zip
      ).exists?
    else
      false
    end
  end
  
  # Helper for contact objects
  def self.contact_on_list?(advertiser, contact)
    address = contact.default_address || {}
    on_list?(
      advertiser,
      email: contact.email,
      address_line1: address['address1'],
      address_city: address['city'],
      address_state: address['state'],
      address_zip: address['zip']
    )
  end
  
  def has_email?
    email.present?
  end
  
  def has_address?
    address_line1.present? && address_city.present? && address_state.present? && address_zip.present?
  end
  
  def display_identifier
    parts = []
    parts << email if has_email?
    parts << formatted_address if has_address?
    parts.join(" / ")
  end
  
  def formatted_address
    return nil unless has_address?
    "#{address_line1}, #{address_city}, #{address_state} #{address_zip}"
  end
  
  private
  
  def email_or_address_present
    unless has_email? || has_address?
      errors.add(:base, "Must provide either email or complete address (line1, city, state, zip)")
    end
  end
  
  def unique_email_or_address
    # Check for duplicate email if present
    if email.present?
      existing = self.class.where(advertiser: advertiser, email: email.downcase.strip)
                          .where.not(id: id)
      if existing.exists?
        errors.add(:email, "is already on the suppression list")
      end
    end
    
    # Check for duplicate address if complete
    if has_address?
      norm_line1 = self.class.normalize_address_field(address_line1)
      existing = self.class.where(advertiser: advertiser)
                          .where("address_line1 = ? AND address_city = ? AND address_state = ? AND address_zip = ?",
                                 norm_line1, address_city.upcase.strip, address_state.upcase.strip, address_zip.strip)
                          .where.not(id: id)
      if existing.exists?
        errors.add(:base, "This address is already on the suppression list")
      end
    end
  end
  
  def normalize_fields
    self.email = email.downcase.strip if email.present?
    
    if address_line1.present?
      self.address_line1 = self.class.normalize_address_field(address_line1)
      self.address_city = address_city.upcase.strip if address_city.present?
      self.address_state = address_state.upcase.strip if address_state.present?
      self.address_zip = address_zip.strip if address_zip.present?
    end
  end
  
  def self.normalize_address_field(address)
    return nil if address.blank?
    # Normalize for consistent matching
    address.upcase.strip.gsub(/[^A-Z0-9\s]/, '').squeeze(' ')
  end
end
