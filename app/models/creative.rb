class Creative < ApplicationRecord
  belongs_to :advertiser
  belongs_to :postcard_template
  belongs_to :created_by_user, class_name: 'User', optional: true
  belongs_to :created_from_campaign, class_name: 'Campaign', optional: true
  belongs_to :approved_by_user, class_name: 'User', optional: true
  
  has_many :campaigns, dependent: :nullify
  
  # Active Storage attachments
  has_one_attached :front_pdf
  has_one_attached :back_pdf
  has_one_attached :thumbnail
  
  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validate :front_pdf_is_pdf
  validate :back_pdf_is_pdf, if: -> { back_pdf.attached? }
  
  # Callbacks
  after_commit :queue_thumbnail_generation, if: :should_generate_thumbnail?
  after_commit :queue_proof_generation, if: :should_generate_proof?
  before_save :reset_approval_on_pdf_change
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
  scope :recent, -> { order(last_used_at: :desc, created_at: :desc) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :by_name, -> { order(:name) }
  
  # Approval status scopes
  scope :approved, -> { where(approval_status: 'approved') }
  scope :pending_approval, -> { where(approval_status: 'pending') }
  scope :rejected, -> { where(approval_status: 'rejected') }
  scope :failed_validation, -> { where(approval_status: 'failed') }
  
  # Check if front PDF is actually a PDF
  def front_pdf_is_pdf
    return unless front_pdf.attached?
    
    unless front_pdf.content_type == 'application/pdf'
      errors.add(:front_pdf, 'must be a PDF file')
    end
  end
  
  # Check if back PDF is actually a PDF
  def back_pdf_is_pdf
    return unless back_pdf.attached?
    
    unless back_pdf.content_type == 'application/pdf'
      errors.add(:back_pdf, 'must be a PDF file')
    end
  end
  
  # Get all unique tags across advertiser's creatives
  def all_tags
    advertiser.creatives.pluck(:tags).flatten.uniq.compact.sort
  end
  
  # Check if both PDFs are attached (front is required, back is optional)
  def complete?
    front_pdf.attached?
  end
  
  # Archive this creative (soft delete)
  def archive!
    update(status: 'archived')
  end
  
  # Restore archived creative
  def restore!
    update(status: 'active')
  end
  
  # Check if this creative has been used
  def used?
    usage_count > 0
  end
  
  # Approval status checks
  def approved?
    approval_status == 'approved'
  end
  
  def pending_approval?
    approval_status == 'pending'
  end
  
  def needs_approval?
    !approved?
  end
  
  def failed_validation?
    approval_status == 'failed'
  end
  
  # Approve this creative
  def approve!(user)
    update!(
      approval_status: 'approved',
      approved_at: Time.current,
      approved_by_user: user,
      rejection_reason: nil
    )
  end
  
  # Reject this creative
  def reject!(user, reason)
    update!(
      approval_status: 'rejected',
      approved_at: nil,
      approved_by_user: user,
      rejection_reason: reason
    )
  end
  
  # Reset approval and regenerate proof
  def regenerate_proof!
    update!(
      approval_status: 'pending',
      lob_proof_url: nil,
      approved_at: nil,
      approved_by_user: nil,
      rejection_reason: nil
    )
    GenerateCreativeProofJob.perform_later(id)
  end
  
  private
  
  # Determine if we should generate a thumbnail
  def should_generate_thumbnail?
    front_pdf.attached? && (
      saved_change_to_id? ||  # New record
      front_pdf.blob.saved_change_to_id?  # Front PDF changed
    )
  end
  
  # Queue thumbnail generation in background
  def queue_thumbnail_generation
    GenerateCreativeThumbnailJob.perform_later(id)
  end
  
  # Determine if we should generate a proof
  def should_generate_proof?
    front_pdf.attached? && (
      saved_change_to_id? ||  # New record
      front_pdf.blob.saved_change_to_id? ||  # Front PDF changed
      (back_pdf.attached? && back_pdf.blob.saved_change_to_id?)  # Back PDF changed
    )
  end
  
  # Queue proof generation in background
  def queue_proof_generation
    GenerateCreativeProofJob.perform_later(id)
  end
  
  # Reset approval status when PDF changes
  def reset_approval_on_pdf_change
    if front_pdf.attached? && will_save_change_to_attribute?(:front_pdf)
      self.approval_status = 'pending'
      self.lob_proof_url = nil
      self.approved_at = nil
      self.approved_by_user_id = nil
      self.rejection_reason = nil
    end
  end
end

