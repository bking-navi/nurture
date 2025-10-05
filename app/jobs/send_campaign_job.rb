class SendCampaignJob < ApplicationJob
  queue_as :default
  
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    advertiser = campaign.advertiser
    
    Rails.logger.info "Starting send for campaign #{campaign.id} (#{campaign.name})"
    
    # Get advertiser's return address
    from_address = LobClient.format_address_editable(
      name: advertiser.name,
      address_line1: advertiser.street_address,
      address_city: advertiser.city,
      address_state: advertiser.state,
      address_zip: advertiser.postal_code,
      address_country: advertiser.country
    )
    
    sent_count = 0
    failed_count = 0
    total_cost = 0
    
    campaign.campaign_contacts.ready_to_send.find_each do |contact|
      begin
        contact.update!(status: :sending)
        
        postcard = LobClient.create_postcard(
          campaign_contact: contact,
          campaign: campaign,
          from_address: from_address
        )
        
        # Store only essential data from Lob response (full response can be 6KB+)
        lob_data = {
          id: postcard.id,
          url: postcard.url,
          expected_delivery_date: postcard.expected_delivery_date,
          created_at: postcard.date_created,
          carrier: postcard.carrier
        }.to_json
        
        contact.update!(
          lob_postcard_id: postcard.id,
          status: :sent,
          tracking_number: nil, # Lob v6+ doesn't provide tracking_number on creation
          tracking_url: postcard.url,
          expected_delivery_date: parse_delivery_date(postcard.expected_delivery_date),
          actual_cost_cents: calculate_cost_cents(postcard),
          lob_response: lob_data
        )
        
        sent_count += 1
        total_cost += contact.actual_cost_cents
        
        Rails.logger.info "Sent postcard #{postcard.id} for contact #{contact.id}"
        
      rescue => e
        contact.update!(
          status: :failed,
          send_error: e.message
        )
        failed_count += 1
        
        Rails.logger.error "Failed to send postcard for contact #{contact.id}: #{e.message}"
      end
      
      # Rate limiting: be conservative with Lob API
      sleep 0.1
    end
    
    # Determine final status based on results
    total_contacts = campaign.recipient_count
    final_status = if sent_count == 0
      :failed  # All postcards failed
    elsif failed_count == 0
      :completed  # All postcards sent successfully
    else
      :completed_with_errors  # Some succeeded, some failed
    end
    
    # Update campaign with final stats
    campaign.update!(
      status: final_status,
      completed_at: Time.current,
      sent_count: sent_count,
      failed_count: failed_count,
      actual_cost_cents: total_cost
    )
    
    Rails.logger.info "Completed campaign #{campaign.id} with status '#{final_status}': #{sent_count} sent, #{failed_count} failed, $#{total_cost/100.0} total"
    
    # Send appropriate completion email
    if final_status == :failed
      CampaignMailer.campaign_failed(campaign, "All postcards failed to send").deliver_later
    else
      CampaignMailer.campaign_sent(campaign).deliver_later
    end
    
  rescue => e
    campaign.update!(status: :failed)
    Rails.logger.error "Campaign #{campaign_id} failed: #{e.message}\n#{e.backtrace.join("\n")}"
    
    # Send failure email
    CampaignMailer.campaign_failed(campaign, e.message).deliver_later
    
    raise # Re-raise to mark job as failed
  end
  
  private
  
  def parse_delivery_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string)
  rescue
    nil
  end
  
  def calculate_cost_cents(postcard)
    # Lob returns price as float (e.g., 1.05)
    # Convert to cents for storage
    price = postcard.try(:price) || 1.05
    (price.to_f * 100).to_i
  end
end

