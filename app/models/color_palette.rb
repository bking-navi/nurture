class ColorPalette < ApplicationRecord
  # Associations
  belongs_to :advertiser, optional: true  # NULL = global/default palette
  has_many :campaigns, dependent: :nullify
  
  # Serialization
  serialize :colors, coder: JSON
  
  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, format: { with: /\A[a-z0-9\-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :colors, presence: true
  validate :validate_colors_structure
  
  # Scopes
  scope :global_palettes, -> { where(advertiser_id: nil) }
  scope :advertiser_palettes, ->(advertiser) { where(advertiser: advertiser) }
  scope :available_for, ->(advertiser) { where(advertiser_id: [nil, advertiser&.id]) }
  scope :defaults, -> { where(is_default: true) }
  
  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? }
  
  # Standard color keys used in templates
  COLOR_KEYS = %w[
    primary
    secondary
    accent
    background
    text
    heading
    cta_bg
    cta_text
  ].freeze
  
  # Get a specific color
  def color(key)
    colors&.dig(key.to_s)
  end
  
  # Get color or default
  def color_or_default(key, default = '#000000')
    color(key) || default
  end
  
  # Check if palette is global
  def global?
    advertiser_id.nil?
  end
  
  # Check if palette is advertiser-specific
  def advertiser_specific?
    !global?
  end
  
  # Display name with scope indicator
  def display_name
    if global?
      name
    else
      "#{name} (Custom)"
    end
  end
  
  private
  
  def generate_slug
    base = name.parameterize
    self.slug = if advertiser_id.present?
      "#{advertiser_id}-#{base}"
    else
      base
    end
  end
  
  def validate_colors_structure
    return if colors.blank?
    
    unless colors.is_a?(Hash)
      errors.add(:colors, "must be a hash")
      return
    end
    
    # Validate at least one color is present
    if colors.empty?
      errors.add(:colors, "must contain at least one color")
      return
    end
    
    # Validate color format (hex colors)
    colors.each do |key, value|
      unless value.match?(/\A#[0-9A-F]{6}\z/i)
        errors.add(:colors, "#{key}: '#{value}' is not a valid hex color (use #RRGGBB format)")
      end
    end
  end
end
