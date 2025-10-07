class GenerateCreativeThumbnailJob < ApplicationJob
  queue_as :default

  def perform(creative_id)
    creative = Creative.find(creative_id)
    return unless creative.front_pdf.attached?
    
    Rails.logger.info "[ThumbnailGen] Starting thumbnail generation for Creative #{creative.id}: #{creative.name}"
    
    creative.front_pdf.open do |file|
      begin
        require 'mini_magick'
        
        # Convert first page of PDF to image
        image = MiniMagick::Image.open(file.path)
        image.format "png"
        image.resize "400x600"  # 2:3 aspect ratio for postcard
        image.quality "85"
        
        # Attach the thumbnail
        creative.thumbnail.attach(
          io: File.open(image.path),
          filename: "#{creative.name.parameterize}-thumb.png",
          content_type: "image/png"
        )
        
        Rails.logger.info "[ThumbnailGen] Successfully generated thumbnail for Creative #{creative.id}"
      rescue => e
        Rails.logger.error "[ThumbnailGen] Failed to generate thumbnail for Creative #{creative.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "[ThumbnailGen] Creative with ID #{creative_id} not found"
  rescue => e
    Rails.logger.error "[ThumbnailGen] Error generating thumbnail for Creative #{creative_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
