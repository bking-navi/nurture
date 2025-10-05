class UpdatePostcardStatusesJob < ApplicationJob
  queue_as :default
  
  # This job should be run daily via a scheduler (e.g., whenever, sidekiq-cron, etc.)
  # For Rails 8 with solid_queue, you can schedule it in config/recurring.yml
  
  def perform
    Rails.logger.info "Starting postcard status update job"
    
    updated_count = 0
    error_count = 0
    
    # Find all postcards that might need status updates
    # (sent or in_transit, and have a Lob postcard ID)
    CampaignContact.where(status: [:sent, :in_transit])
                   .where.not(lob_postcard_id: nil)
                   .find_each do |contact|
      begin
        postcard = LobClient.get_postcard(contact.lob_postcard_id)
        
        new_status = map_lob_status(postcard.status)
        
        # Only update if status changed
        if contact.status != new_status
          contact.update!(
            status: new_status,
            delivered_at: (Time.current if new_status == 'delivered'),
            lob_response: postcard.to_h
          )
          
          # Update campaign counts
          contact.campaign.update_counts!
          
          updated_count += 1
          Rails.logger.info "Updated contact #{contact.id} to status: #{new_status}"
        end
        
      rescue => e
        error_count += 1
        Rails.logger.error "Failed to update postcard status for contact #{contact.id}: #{e.message}"
      end
      
      # Rate limiting
      sleep 0.1
    end
    
    Rails.logger.info "Postcard status update complete: #{updated_count} updated, #{error_count} errors"
  end
  
  private
  
  def map_lob_status(lob_status)
    case lob_status.to_s.downcase
    when 'in_transit', 'in local area', 'processed for delivery'
      'in_transit'
    when 'delivered', 'mailed'
      'delivered'
    when 'returned_to_sender', 'returned'
      'returned'
    when 'failed'
      'failed'
    else
      'sent' # Default fallback
    end
  end
end

