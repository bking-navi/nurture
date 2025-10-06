class Segment < ApplicationRecord
  belongs_to :advertiser
  
  # Serialize filters as JSON
  serialize :filters, coder: JSON
  
  # Validations
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :advertiser_id, presence: true
  
  # Callbacks
  after_initialize :set_default_filters, if: :new_record?
  before_save :normalize_filters
  before_save :update_contact_count
  
  # Get contacts matching this segment's filters
  def contacts
    query = advertiser.contacts
                      .where("default_address->>'address1' IS NOT NULL")
                      .where("default_address->>'city' IS NOT NULL")
                      .where("default_address->>'state' IS NOT NULL")
                      .where("default_address->>'zip' IS NOT NULL")
    
    # Apply source filter
    if filters['source'].present?
      case filters['source']
      when 'shopify'
        query = query.where(source_type: 'ShopifyStore')
      when 'manual'
        query = query.where(source_type: 'Advertiser')
      end
    end
    
    # Apply search filter
    if filters['search'].present?
      search_term = "%#{filters['search']}%"
      query = query.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
        search_term, search_term, search_term
      )
    end
    
    # Apply city filter
    if filters['city'].present?
      query = query.where("default_address->>'city' ILIKE ?", filters['city'])
    end
    
    # Apply state filter
    if filters['state'].present?
      query = query.where("default_address->>'state' = ?", filters['state'].upcase)
    end
    
    # Apply zip filter
    if filters['zip'].present?
      query = query.where("default_address->>'zip' = ?", filters['zip'])
    end
    
    query
  end
  
  # Update the cached contact count
  def update_contact_count
    self.contact_count = contacts.count
  end
  
  # Refresh the contact count
  def refresh_count!
    update_contact_count
    save
  end
  
  private
  
  def set_default_filters
    self.filters ||= {}
  end
  
  def normalize_filters
    return unless filters.is_a?(Hash)
    
    # Remove empty string values
    self.filters = filters.reject { |_, v| v.blank? }
    
    # Uppercase state code if present
    if filters['state'].present?
      self.filters['state'] = filters['state'].upcase
    end
  end
end
