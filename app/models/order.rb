class Order < ApplicationRecord
  belongs_to :advertiser
  belongs_to :source, polymorphic: true
  belongs_to :contact, optional: true

  # Enums
  enum :financial_status, {
    pending: 0,
    authorized: 1,
    partially_paid: 2,
    paid: 3,
    partially_refunded: 4,
    refunded: 5,
    voided: 6
  }, prefix: true

  enum :fulfillment_status, {
    fulfilled: 0,
    partial: 1,
    unfulfilled: 2
  }, prefix: true

  # Validations
  validates :advertiser_id, presence: true
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: [:source_type, :source_id] }
  validates :total_price, presence: true
  validates :currency, presence: true
  validates :ordered_at, presence: true

  # Scopes
  scope :from_shopify, -> { where(source_type: 'ShopifyStore') }
  scope :paid_orders, -> { where(financial_status: :paid) }
  scope :recent, -> { order(ordered_at: :desc) }
  scope :in_date_range, ->(start_date, end_date) { where(ordered_at: start_date..end_date) }

  # Instance methods
  def from_shopify?
    source_type == 'ShopifyStore'
  end

  def paid?
    financial_status == 'paid'
  end

  def refunded?
    financial_status.to_s.include?('refunded')
  end

  def shopify_url
    return unless from_shopify?
    "#{source.shopify_admin_url}/orders/#{external_id}"
  end

  def customer_name
    if contact
      contact.display_name
    elsif shipping_address && shipping_address['name']
      shipping_address['name']
    else
      email
    end
  end
end

