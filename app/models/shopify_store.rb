class ShopifyStore < ApplicationRecord
  belongs_to :advertiser
  has_many :contacts, as: :source, dependent: :destroy
  has_many :orders, as: :source, dependent: :destroy
  has_many :products, as: :source, dependent: :destroy
  has_many :sync_jobs, dependent: :destroy

  # Encrypt access token (Rails 7+)
  encrypts :access_token

  # Enums
  enum :status, {
    connected: 0,
    disconnected: 1,
    error: 2,
    syncing: 3
  }

  enum :last_sync_status, {
    success: 0,
    failed: 1,
    partial: 2
  }, prefix: true

  enum :sync_frequency, {
    realtime: 0,
    every_15_min: 1,
    hourly: 2,
    every_6_hours: 3,
    daily: 4,
    manual: 5
  }

  # Validations
  validates :shop_domain, presence: true, format: { with: /\.myshopify\.com\z/ }
  validates :shop_domain, uniqueness: { scope: :advertiser_id }
  validates :access_token, presence: true
  validates :sync_frequency, presence: true

  # Scopes
  scope :ready_to_sync, -> { where(status: :connected) }
  scope :needs_sync, ->(frequency) { ready_to_sync.where(sync_frequency: frequency) }

  # Instance methods
  def connected?
    status == 'connected'
  end

  def needs_reconnection?
    status.in?(['disconnected', 'error'])
  end

  def display_name
    name.presence || shop_domain
  end

  def api_client
    @api_client ||= ShopifyClient.new(self)
  end

  def sync_now!(triggered_by_user: nil)
    ShopifyFullSyncJob.perform_later(id, triggered_by_user&.id)
  end

  def disconnect!
    update!(
      status: :disconnected,
      webhooks_installed: false,
      last_sync_error: 'Store disconnected by user'
    )
    # TODO: Uninstall webhooks from Shopify
  end

  def shopify_admin_url
    "https://#{shop_domain}/admin"
  end
end

