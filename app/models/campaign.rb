class Campaign < ApplicationRecord
  belongs_to :advertiser
  belongs_to :created_by_user, class_name: 'User'
  has_many :campaign_contacts, dependent: :destroy
  
  # Serialize JSON fields for SQLite compatibility
  serialize :merge_variables, coder: JSON
  
  enum :status, {
    draft: 0,
    scheduled: 1,
    processing: 2,
    completed: 3,           # All postcards sent successfully
    completed_with_errors: 4, # Some postcards failed
    failed: 5,              # All postcards failed or campaign error
    cancelled: 6
  }
  
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :advertiser_id, presence: true
  validates :created_by_user_id, presence: true
  validates :status, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :scheduled_for_sending, -> { where(status: 'scheduled').where('scheduled_at <= ?', Time.current) }
  
  # Cost calculations (in cents)
  def estimated_cost_dollars
    (estimated_cost_cents || 0) / 100.0
  end
  
  def actual_cost_dollars
    (actual_cost_cents || 0) / 100.0
  end
  
  def calculate_estimated_cost!
    return 0 if campaign_contacts.empty?
    
    # Cost for 6x9 postcard with USPS First Class: $1.05
    cost_per_postcard = 105 # cents
    total = campaign_contacts.count * cost_per_postcard
    
    update!(estimated_cost_cents: total)
    campaign_contacts.update_all(estimated_cost_cents: cost_per_postcard)
    
    total
  end
  
  # State checks
  def sendable?
    draft? && recipient_count > 0 && template_id.present?
  end
  
  def deletable?
    draft?
  end
  
  def editable?
    draft?
  end
  
  def successfully_sent?
    completed? || completed_with_errors?
  end
  
  def has_errors?
    completed_with_errors? || failed?
  end
  
  # Actions
  def send_now!
    raise "Campaign not ready to send" unless sendable?
    
    update!(status: :processing, sent_at: Time.current)
    SendCampaignJob.perform_later(id)
  end
  
  def cancel!
    raise "Cannot cancel campaign in #{status} status" unless scheduled?
    
    update!(status: :cancelled)
  end
  
  # Stats
  def update_counts!
    update!(
      recipient_count: campaign_contacts.count,
      sent_count: campaign_contacts.where(status: [:sent, :in_transit, :delivered]).count,
      failed_count: campaign_contacts.where(status: :failed).count,
      delivered_count: campaign_contacts.where(status: :delivered).count
    )
  end
  
  def completion_percentage
    return 0 if recipient_count.zero?
    
    completed = sent_count + failed_count
    (completed.to_f / recipient_count * 100).round
  end
end

