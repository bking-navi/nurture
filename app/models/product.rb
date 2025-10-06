class Product < ApplicationRecord
  belongs_to :advertiser
  belongs_to :source, polymorphic: true

  # Enums
  enum :status, {
    active: 0,
    archived: 1,
    draft: 2
  }

  # Validations
  validates :advertiser_id, presence: true
  validates :title, presence: true
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: [:source_type, :source_id] }

  # Scopes
  scope :from_shopify, -> { where(source_type: 'ShopifyStore') }
  scope :active_products, -> { where(status: :active) }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
  scope :by_type, ->(type) { where(product_type: type) }
  scope :by_vendor, ->(vendor) { where(vendor: vendor) }

  # Instance methods
  def from_shopify?
    source_type == 'ShopifyStore'
  end

  def shopify_url
    return unless from_shopify?
    "#{source.shopify_admin_url}/products/#{external_id}"
  end

  def in_stock?
    return false if variants.blank?
    variants.any? { |v| v['inventory_quantity'].to_i > 0 }
  end

  def primary_image_url
    images&.first&.dig('src') || images&.first&.dig('url')
  end

  def variant_titles
    variants.map { |v| v['title'] }.compact
  end

  def price_range
    return nil if variants.blank?
    prices = variants.map { |v| v['price'].to_f }.compact
    return nil if prices.empty?
    
    min_price = prices.min
    max_price = prices.max
    
    if min_price == max_price
      "$#{min_price}"
    else
      "$#{min_price} - $#{max_price}"
    end
  end
end

