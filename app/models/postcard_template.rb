class PostcardTemplate < ApplicationRecord
  # Associations
  has_many :campaigns, dependent: :nullify
  has_one_attached :thumbnail
  has_one_attached :preview_image
  
  # Serialization
  serialize :front_fields, coder: JSON
  serialize :back_fields, coder: JSON
  serialize :default_values, coder: JSON
  
  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :category, presence: true, inclusion: { in: %w[offer product event welcome seasonal] }
  validates :front_html, presence: true
  validates :back_html, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_sort_order, -> { order(sort_order: :asc, created_at: :asc) }
  scope :by_category, ->(category) { where(category: category) }
  
  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }
  
  # Categories with labels
  CATEGORIES = {
    'offer' => 'Bold Offer',
    'product' => 'Product Showcase',
    'event' => 'Event Invitation',
    'welcome' => 'Welcome/Thank You',
    'seasonal' => 'Seasonal/Holiday'
  }.freeze
  
  def category_label
    CATEGORIES[category] || category.titleize
  end
  
  # Render HTML with data
  def render_front(data = {})
    render_html(front_html, data.merge(default_values || {}))
  end
  
  def render_back(data = {})
    render_html(back_html, data.merge(default_values || {}))
  end
  
  # Get field configuration
  def front_field_configs
    front_fields || []
  end
  
  def back_field_configs
    back_fields || []
  end
  
  # Get all field configs combined
  def all_field_configs
    front_field_configs + back_field_configs
  end
  
  # Get field names
  def front_field_names
    front_field_configs.map { |f| f['name'] }
  end
  
  def back_field_names
    back_field_configs.map { |f| f['name'] }
  end
  
  def all_field_names
    front_field_names + back_field_names
  end
  
  private
  
  def generate_slug
    self.slug = name.parameterize if name.present?
  end
  
  def render_html(html, data)
    result = html.dup
    
    # Replace all {{variable}} with actual values
    data.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    
    # Handle any unreplaced variables (replace with empty string)
    result.gsub!(/\{\{(\w+)\}\}/, '')
    
    result
  end
end
