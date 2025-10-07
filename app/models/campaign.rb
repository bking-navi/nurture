class Campaign < ApplicationRecord
  belongs_to :advertiser
  belongs_to :created_by_user, class_name: 'User'
  belongs_to :postcard_template, optional: true
  belongs_to :color_palette, optional: true
  belongs_to :creative, optional: true
  has_many :campaign_contacts, dependent: :destroy
  
  # Active Storage for PDF uploads
  has_one_attached :front_pdf
  has_one_attached :back_pdf
  
  # Callbacks
  after_create :increment_creative_usage, if: :creative_id?
  
  # Serialize JSON fields for SQLite compatibility
  serialize :merge_variables, coder: JSON
  serialize :template_data, coder: JSON
  
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
    draft? && recipient_count > 0 && has_design?
  end
  
  def has_design?
    # Campaign has design if it has either:
    # 1. Creative from library
    # 2. PDF uploads (front_pdf and back_pdf)
    # 3. New custom template system (postcard_template_id)
    # 4. Old simple system (template_id or front_message/back_message)
    creative_id.present? ||
    (front_pdf.attached? && back_pdf.attached?) ||
    postcard_template_id.present? || 
    template_id.present? || 
    front_message.present? || 
    back_message.present?
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
  
  # Template rendering methods
  def using_template?
    postcard_template_id.present?
  end
  
  def template_data_with_defaults
    data = (template_data || {}).symbolize_keys
    
    # Add advertiser defaults
    data[:logo_url] ||= advertiser.logo_url if advertiser.respond_to?(:logo_url)
    data[:company_name] ||= advertiser.name
    data[:website] ||= advertiser.website_url
    data[:phone] ||= advertiser.phone if advertiser.respond_to?(:phone)
    
    # Add color palette colors
    if color_palette
      color_palette.colors.each do |key, value|
        data["color_#{key}".to_sym] ||= value
      end
    end
    
    data
  end
  
  def render_front_html(contact_data = {})
    return front_message if !using_template?
    
    data = template_data_with_defaults.merge(contact_data.symbolize_keys)
    postcard_template.render_front(data)
  end
  
  def render_back_html(contact_data = {})
    return back_message if !using_template?
    
    data = template_data_with_defaults.merge(contact_data.symbolize_keys)
    postcard_template.render_back(data)
  end
  
  # Creative management methods
  def front_pdf_file
    creative&.front_pdf || front_pdf
  end
  
  def back_pdf_file
    creative&.back_pdf || back_pdf || creative&.postcard_template&.default_back_pdf
  end
  
  def using_creative?
    creative_id.present?
  end
  
  private
  
  def increment_creative_usage
    creative.increment!(:usage_count)
    creative.touch(:last_used_at)
  end
end

