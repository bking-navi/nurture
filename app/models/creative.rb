class Creative < ApplicationRecord
  belongs_to :advertiser
  belongs_to :postcard_template
  belongs_to :created_by_user, class_name: 'User', optional: true
  belongs_to :created_from_campaign, class_name: 'Campaign', optional: true
  
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
  after_commit :generate_thumbnail, if: :should_generate_thumbnail?
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
  scope :recent, -> { order(last_used_at: :desc, created_at: :desc) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :by_name, -> { order(:name) }
  
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
  
  private
  
  # Determine if we should generate a thumbnail
  def should_generate_thumbnail?
    front_pdf.attached? && (
      saved_change_to_id? ||  # New record
      front_pdf.blob.saved_change_to_id?  # Front PDF changed
    )
  end
  
  # Generate thumbnail from front PDF
  def generate_thumbnail
    return unless front_pdf.attached?
    
    # Use MiniMagick to convert first page of PDF to PNG
    front_pdf.open do |file|
      begin
        require 'mini_magick'
        
        # Convert first page of PDF to image
        image = MiniMagick::Image.open(file.path)
        image.format "png"
        image.resize "400x600"  # 2:3 aspect ratio for postcard
        image.quality "85"
        
        # Attach the thumbnail
        thumbnail.attach(
          io: File.open(image.path),
          filename: "#{name.parameterize}-thumb.png",
          content_type: "image/png"
        )
      rescue => e
        Rails.logger.error "Failed to generate thumbnail for Creative #{id}: #{e.message}"
      end
    end
  end
end

