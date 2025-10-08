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
    suppressed_count = 0
    total_cost = 0
    
    # Debug logging
    Rails.logger.info "[SendCampaign] Campaign #{campaign.id}: override_suppression=#{campaign.override_suppression}"
    Rails.logger.info "[SendCampaign] Total contacts: #{campaign.campaign_contacts.count}"
    Rails.logger.info "[SendCampaign] Pending contacts: #{campaign.campaign_contacts.where(status: :pending).count}"
    Rails.logger.info "[SendCampaign] Suppressed contacts: #{campaign.campaign_contacts.where(suppressed: true).count}"
    sendable_contacts = campaign.campaign_contacts.sendable(campaign.override_suppression)
    Rails.logger.info "[SendCampaign] Sendable contacts: #{sendable_contacts.count}"
    
    # Use sendable scope which respects suppression settings
    sendable_contacts.find_each do |contact|
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
        
        # Update last_mailed_at on the linked Contact
        if contact.contact.present?
          contact.contact.update_last_mailed!
        end
        
        sent_count += 1
        total_cost += contact.actual_cost_cents
        
        Rails.logger.info "Sent postcard #{postcard.id} for contact #{contact.id}"
        
      rescue => e
        # Extract user-friendly error message from Lob API response
        error_message = parse_lob_error(e)
        
        contact.update!(
          status: :failed,
          send_error: error_message
        )
        failed_count += 1
        
        Rails.logger.error "Failed to send postcard for contact #{contact.id}: #{error_message}"
      end
      
      # Rate limiting: be conservative with Lob API
      sleep 0.1
    end
    
    # Count suppressed contacts that were skipped
    if !campaign.override_suppression
      suppressed_count = campaign.campaign_contacts.where(suppressed: true, status: :pending).count
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
    
    log_message = "Completed campaign #{campaign.id} with status '#{final_status}': #{sent_count} sent, #{failed_count} failed"
    log_message += ", #{suppressed_count} suppressed" if suppressed_count > 0
    log_message += ", $#{total_cost/100.0} total"
    Rails.logger.info log_message
    
    # Charge advertiser's balance if campaign sent any postcards
    if sent_count > 0 && total_cost > 0 && !campaign.charged?
      begin
        advertiser.charge_for_campaign!(campaign, processed_by: campaign.created_by_user)
        Rails.logger.info "Charged advertiser #{advertiser.id} $#{total_cost/100.0} for campaign #{campaign.id}"
      rescue => e
        Rails.logger.error "Failed to charge advertiser #{advertiser.id} for campaign #{campaign.id}: #{e.message}"
        # Don't fail the job if charging fails - the campaign was already sent
        # Platform admin can manually resolve billing issues
      end
    end
    
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
  
  def parse_lob_error(error)
    # Extract meaningful error message from Lob API response
    error_string = error.message
    
    # Try to parse JSON error from Lob API
    if error_string =~ /Response body: ({.*})/m
      begin
        json_match = error_string.match(/Response body: ({.*})/m)
        error_data = JSON.parse(json_match[1]) if json_match
        
        if error_data && error_data['error']
          lob_message = error_data['error']['message']
          error_code = error_data['error']['code']
          
          # Make address-related errors very clear
          case error_code
          when 'failed_deliverability_strictness'
            return "❌ Address Undeliverable: This address failed USPS verification and cannot receive mail. Please verify the address is correct."
          when 'invalid_address'
            return "❌ Invalid Address: This address format is invalid. Please check street, city, state, and ZIP code."
          when 'address_length_exceeds_limit'
            return "❌ Address Too Long: One or more address fields exceed the maximum length."
          else
            # Return the Lob message for other errors
            return "#{lob_message}"
          end
        end
      rescue JSON::ParserError
        # Fall through to default message
      end
    end
    
    # Fallback: try to extract just the error message
    if error_string.include?('address')
      "Address validation failed. Please verify the recipient's address is correct."
    else
      # Return a shortened version of the error
      error_string.split("\n").first || error_string[0..200]
    end
  end
  
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

