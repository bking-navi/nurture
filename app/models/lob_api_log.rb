class LobApiLog < ApplicationRecord
  belongs_to :advertiser
  belongs_to :campaign, optional: true
  
  # Validations
  validates :endpoint, presence: true
  validates :method, presence: true
  validates :success, inclusion: { in: [true, false] }
  
  # Scopes
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_campaign, ->(campaign) { where(campaign: campaign) }
  scope :for_advertiser, ->(advertiser) { where(advertiser: advertiser) }
  scope :today, -> { where('created_at >= ?', Time.current.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', Time.current.beginning_of_week) }
  scope :this_month, -> { where('created_at >= ?', Time.current.beginning_of_month) }
  scope :postcards, -> { where(lob_object_type: 'postcard') }
  scope :verifications, -> { where(endpoint: '/us_verifications') }
  
  # Enum for common endpoints
  enum :lob_object_type, {
    postcard: 'postcard',
    verification: 'verification',
    address: 'address',
    other: 'other'
  }, prefix: true
  
  # Helper methods
  def cost_dollars
    (cost_cents || 0) / 100.0
  end
  
  def duration_seconds
    duration_ms ? duration_ms / 1000.0 : nil
  end
  
  def status_badge_color
    success? ? 'green' : 'red'
  end
  
  def endpoint_display
    endpoint.gsub('/v1/', '').split('?').first
  end
  
  def readable_endpoint
    case endpoint_display
    when /postcards/
      'Create Postcard'
    when /us_verifications/
      'Verify Address'
    when /addresses/
      'Create Address'
    else
      endpoint_display.titleize
    end
  end
  
  # Stats methods
  def self.total_cost_cents
    sum(:cost_cents)
  end
  
  def self.total_cost_dollars
    total_cost_cents / 100.0
  end
  
  def self.success_rate
    total = count
    return 0 if total.zero?
    (successful.count.to_f / total * 100).round(1)
  end
  
  def self.average_duration_ms
    average(:duration_ms)&.round || 0
  end
end
