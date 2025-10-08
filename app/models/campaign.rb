class Campaign < ApplicationRecord
  belongs_to :advertiser
  belongs_to :created_by_user, class_name: 'User'
  belongs_to :postcard_template, optional: true
  belongs_to :color_palette, optional: true
  belongs_to :creative, optional: true
  has_many :campaign_contacts, dependent: :destroy
  has_many :suppressed_contacts, -> { where(suppressed: true) }, class_name: 'CampaignContact'
  
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
  COST_PER_POSTCARD_CENTS = 105  # $1.05 per 6x9 postcard
  
  def estimated_cost_dollars
    (estimated_cost_cents || 0) / 100.0
  end
  
  def actual_cost_dollars
    (actual_cost_cents || 0) / 100.0
  end
  
  def calculate_estimated_cost!
    return 0 if campaign_contacts.empty?
    
    cost_per_postcard = COST_PER_POSTCARD_CENTS
    total = campaign_contacts.count * cost_per_postcard
    
    update!(estimated_cost_cents: total)
    campaign_contacts.update_all(estimated_cost_cents: cost_per_postcard)
    
    total
  end
  
  def charged?
    charged_at.present?
  end
  
  def chargeable?
    !charged? && actual_cost_cents.present? && actual_cost_cents > 0
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
    
    # Check if advertiser has sufficient balance
    unless advertiser.can_send_campaign?(self)
      raise "Insufficient balance. Please add funds to your account."
    end
    
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
  
  def suppressed_count
    # Only count contacts that are suppressed AND still pending (not sent)
    campaign_contacts.where(suppressed: true, status: :pending).count
  end
  
  def sendable_count
    # If override is on, send to all pending contacts
    # If override is off, only send to non-suppressed pending contacts
    campaign_contacts.sendable(override_suppression).count
  end
  
  def completion_percentage
    return 0 if recipient_count.zero?
    
    completed = sent_count + failed_count
    (completed.to_f / recipient_count * 100).round
  end
  
  # Suppression settings (campaign overrides or advertiser defaults)
  def suppression_settings
    {
      recent_order_days: recent_order_suppression_days || advertiser.recent_order_suppression_days,
      recent_mail_days: recent_mail_suppression_days || advertiser.recent_mail_suppression_days,
      dnm_enabled: advertiser.dnm_enabled
    }
  end
  
  def check_suppression(contact)
    settings = suppression_settings
    reasons = []
    
    # Check DNM list
    if settings[:dnm_enabled] && contact.on_suppression_list?
      reasons << "On Do Not Mail list"
    end
    
    # Check recent orders
    if settings[:recent_order_days] > 0 && contact.last_order_at.present?
      days_since_order = ((Time.current - contact.last_order_at) / 1.day).to_i
      if days_since_order < settings[:recent_order_days]
        reasons << "Ordered #{days_since_order} days ago (suppressing orders within #{settings[:recent_order_days]} days)"
      end
    end
    
    # Check recent mail
    if settings[:recent_mail_days] > 0 && contact.last_mailed_at.present?
      days_since_mail = ((Time.current - contact.last_mailed_at) / 1.day).to_i
      if days_since_mail < settings[:recent_mail_days]
        reasons << "Mailed #{days_since_mail} days ago (suppressing mail within #{settings[:recent_mail_days]} days)"
      end
    end
    
    {
      suppressed: reasons.any?,
      reason: reasons.join("; ")
    }
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

