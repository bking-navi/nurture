class CampaignContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :set_campaign
  before_action :verify_campaign_editable!, except: [:retry]
  
  layout "sidebar"
  
  def new
    @contact = @campaign.campaign_contacts.build
  end
  
  def create
    @contact = @campaign.campaign_contacts.build(contact_params)
    
    # Check suppression if linked to a Contact
    if @contact.contact.present?
      suppression_result = @campaign.check_suppression(@contact.contact)
      if suppression_result[:suppressed]
        @contact.suppressed = true
        @contact.suppression_reason = suppression_result[:reason]
      end
    end
    
    if @contact.save
      # Optionally validate address with Lob
      if params[:validate_address] == '1'
        @contact.validate_address!
      end
      
      @campaign.update_counts!
      
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  notice: 'Recipient added.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    @contact = @campaign.campaign_contacts.find(params[:id])
    @contact.destroy
    
    @campaign.update_counts!
    
    redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                notice: 'Recipient removed.'
  end
  
  def retry
    @contact = @campaign.campaign_contacts.find(params[:id])
    
    unless @contact.failed?
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  alert: 'Only failed postcards can be retried.'
      return
    end
    
    # Reset the contact to pending status
    @contact.update!(
      status: :pending,
      send_error: nil,
      lob_postcard_id: nil,
      lob_response: nil
    )
    
    # Get advertiser's return address
    from_address = LobClient.format_address_editable(
      name: @advertiser.name,
      address_line1: @advertiser.street_address,
      address_city: @advertiser.city,
      address_state: @advertiser.state,
      address_zip: @advertiser.postal_code,
      address_country: @advertiser.country
    )
    
    # Retry sending immediately
    begin
      @contact.update!(status: :sending)
      
      postcard = LobClient.create_postcard(
        campaign_contact: @contact,
        campaign: @campaign,
        from_address: from_address
      )
      
      # Store only essential data from Lob response to avoid session overflow
      lob_data = {
        id: postcard.id,
        url: postcard.url,
        expected_delivery_date: postcard.expected_delivery_date,
        created_at: postcard.date_created
      }.to_json
      
      @contact.update!(
        lob_postcard_id: postcard.id,
        status: :sent,
        tracking_number: nil,
        tracking_url: postcard.url,
        expected_delivery_date: Date.parse(postcard.expected_delivery_date.to_s),
        actual_cost_cents: (postcard.try(:price).to_f * 100).to_i,
        lob_response: lob_data
      )
      
      # Update campaign counts and costs
      @campaign.update_counts!
      @campaign.update!(
        actual_cost_cents: @campaign.campaign_contacts.sum(:actual_cost_cents)
      )
      
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  notice: "Postcard retry successful!"
    rescue => e
      # Parse Lob error to get user-friendly message
      error_msg = parse_lob_error(e)
      
      @contact.update!(
        status: :failed,
        send_error: error_msg
      )
      
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  alert: "Retry failed: #{error_msg}"
    end
  end
  
  def import_csv
    file = params[:csv_file]
    
    unless file.present?
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: 'Please select a CSV file.'
      return
    end
    
    importer = CsvImporter.new(campaign: @campaign, file: file)
    result = importer.import
    
    if result[:success]
      if result[:invalid] > 0
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                    notice: "Imported #{result[:imported]} recipients. #{result[:invalid]} invalid (see below).",
                    alert: result[:errors].first(5).join('; ')
      else
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                    notice: "Successfully imported #{result[:imported]} recipients."
      end
    else
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: "Import failed: #{result[:errors].join(', ')}"
    end
  end
  
  def download_sample
    send_data CsvImporter.sample_csv,
              filename: "campaign_recipients_sample.csv",
              type: "text/csv"
  end
  
  def preview_shopify
    shopify_store = @advertiser.shopify_stores.find(params[:shopify_store_id])
    
    # Build query for contacts - only US addresses with complete data
    contacts = shopify_store.contacts
                           .where("default_address->>'address1' IS NOT NULL")
                           .where("default_address->>'city' IS NOT NULL")
                           .where("default_address->>'state' IS NOT NULL")
                           .where("default_address->>'zip' IS NOT NULL")
                           .where("default_address->>'country_code' IN ('US', 'USA') OR default_address->>'country' IN ('US', 'USA', 'United States')")
    
    # Apply location filters
    if params[:city].present?
      contacts = contacts.where("default_address->>'city' ILIKE ?", params[:city])
    end
    
    if params[:state].present?
      contacts = contacts.where("default_address->>'state' ILIKE ?", params[:state])
    end
    
    if params[:zip].present?
      contacts = contacts.where("default_address->>'zip' = ?", params[:zip])
    end
    
    count = contacts.count
    
    # Build location summary
    location_parts = []
    location_parts << params[:city] if params[:city].present?
    location_parts << params[:state] if params[:state].present?
    location_parts << params[:zip] if params[:zip].present?
    locations = location_parts.any? ? "in #{location_parts.join(', ')}" : "from all locations"
    
    render json: { 
      count: count,
      locations: locations
    }
  end
  
  def import_shopify
    shopify_store = @advertiser.shopify_stores.find(params[:shopify_store_id])
    
    # Build query for contacts - only US addresses with complete data  
    contacts = shopify_store.contacts
                           .where("default_address->>'address1' IS NOT NULL")
                           .where("default_address->>'city' IS NOT NULL")
                           .where("default_address->>'state' IS NOT NULL")
                           .where("default_address->>'zip' IS NOT NULL")
                           .where("default_address->>'country_code' IN ('US', 'USA') OR default_address->>'country' IN ('US', 'USA', 'United States')")
    
    # Apply same location filters as preview
    if params[:city].present?
      contacts = contacts.where("default_address->>'city' ILIKE ?", params[:city])
    end
    
    if params[:state].present?
      contacts = contacts.where("default_address->>'state' ILIKE ?", params[:state])
    end
    
    if params[:zip].present?
      contacts = contacts.where("default_address->>'zip' = ?", params[:zip])
    end
    
    imported_count = 0
    skipped_count = 0
    errors = []
    
    contacts.find_each do |contact|
      address = contact.default_address
      
      # Create CampaignContact (filtering already done in query)
      campaign_contact = @campaign.campaign_contacts.build(
        contact: contact,
        first_name: contact.first_name,
        last_name: contact.last_name,
        email: contact.email,
        phone: contact.phone,
        address_line1: address['address1'],
        address_line2: address['address2'],
        address_city: address['city'],
        address_state: address['state'],
        address_zip: address['zip']
      )
      
      # Check suppression
      suppression_result = @campaign.check_suppression(contact)
      if suppression_result[:suppressed]
        campaign_contact.suppressed = true
        campaign_contact.suppression_reason = suppression_result[:reason]
      end
      
      if campaign_contact.save
        imported_count += 1
      else
        errors << "#{contact.full_name}: #{campaign_contact.errors.full_messages.join(', ')}"
      end
    end
    
    # Update campaign counts
    @campaign.update_counts!
    
    if imported_count > 0
      message = "Successfully imported #{imported_count} US contact#{'s' unless imported_count == 1} from Shopify"
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  notice: message
    else
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: "No US contacts found matching your criteria. Note: Only US addresses are supported."
    end
  end
  
  def preview_contacts
    # Build query for contacts with US addresses
    contacts = @advertiser.contacts
                         .where("default_address->>'address1' IS NOT NULL")
                         .where("default_address->>'city' IS NOT NULL")
                         .where("default_address->>'state' IS NOT NULL")
                         .where("default_address->>'zip' IS NOT NULL")
                         .where("default_address->>'country_code' IN ('US', 'USA') OR default_address IS NULL")
    
    # Apply source filter
    if params[:source].present?
      case params[:source]
      when 'shopify'
        contacts = contacts.where(source_type: 'ShopifyStore')
      when 'manual'
        contacts = contacts.where(source_type: 'Advertiser')
      end
    end
    
    # Apply search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      contacts = contacts.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
        search_term, search_term, search_term
      )
    end
    
    count = contacts.count
    
    render json: { count: count }
  end
  
  def import_contacts
    # Build query for contacts with US addresses
    contacts = @advertiser.contacts
                         .where("default_address->>'address1' IS NOT NULL")
                         .where("default_address->>'city' IS NOT NULL")
                         .where("default_address->>'state' IS NOT NULL")
                         .where("default_address->>'zip' IS NOT NULL")
                         .where("default_address->>'country_code' IN ('US', 'USA') OR default_address IS NULL")
    
    # Apply source filter
    if params[:source].present?
      case params[:source]
      when 'shopify'
        contacts = contacts.where(source_type: 'ShopifyStore')
      when 'manual'
        contacts = contacts.where(source_type: 'Advertiser')
      end
    end
    
    # Apply search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      contacts = contacts.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
        search_term, search_term, search_term
      )
    end
    
    imported_count = 0
    skipped_count = 0
    errors = []
    
    contacts.find_each do |contact|
      address = contact.default_address
      
      # Skip if already added to this campaign
      if @campaign.campaign_contacts.exists?(contact: contact)
        skipped_count += 1
        next
      end
      
      # Create CampaignContact
      campaign_contact = @campaign.campaign_contacts.build(
        contact: contact,
        first_name: contact.first_name,
        last_name: contact.last_name,
        email: contact.email,
        phone: contact.phone,
        address_line1: address['address1'],
        address_line2: address['address2'],
        address_city: address['city'],
        address_state: address['state'],
        address_zip: address['zip']
      )
      
      # Check suppression
      suppression_result = @campaign.check_suppression(contact)
      if suppression_result[:suppressed]
        campaign_contact.suppressed = true
        campaign_contact.suppression_reason = suppression_result[:reason]
      end
      
      if campaign_contact.save
        imported_count += 1
      else
        errors << "#{contact.full_name}: #{campaign_contact.errors.full_messages.join(', ')}"
      end
    end
    
    # Update campaign counts
    @campaign.update_counts!
    
    if imported_count > 0
      message = "Successfully imported #{imported_count} contact#{'s' unless imported_count == 1}"
      message += " (#{skipped_count} already added)" if skipped_count > 0
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  notice: message
    else
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: "No contacts found matching your criteria."
    end
  end
  
  def update_suppression_override
    # Handle both boolean and string values
    override = ActiveModel::Type::Boolean.new.cast(params[:override_suppression])
    
    if @campaign.update(override_suppression: override)
      render json: { 
        success: true, 
        override: override,
        message: override ? 'Suppression override enabled' : 'Suppression override disabled'
      }
    else
      render json: { 
        success: false, 
        errors: @campaign.errors.full_messages 
      }, status: :unprocessable_entity
    end
  end
  
  def import_segment
    segment = @advertiser.segments.find(params[:segment_id])
    contacts = segment.contacts
    
    imported_count = 0
    skipped_count = 0
    errors = []
    
    contacts.find_each do |contact|
      address = contact.default_address
      
      # Skip if already added to this campaign
      if @campaign.campaign_contacts.exists?(contact: contact)
        skipped_count += 1
        next
      end
      
      # Create CampaignContact
      campaign_contact = @campaign.campaign_contacts.build(
        contact: contact,
        first_name: contact.first_name,
        last_name: contact.last_name,
        email: contact.email,
        phone: contact.phone,
        address_line1: address['address1'],
        address_line2: address['address2'],
        address_city: address['city'],
        address_state: address['state'],
        address_zip: address['zip']
      )
      
      # Check suppression
      suppression_result = @campaign.check_suppression(contact)
      if suppression_result[:suppressed]
        campaign_contact.suppressed = true
        campaign_contact.suppression_reason = suppression_result[:reason]
      end
      
      if campaign_contact.save
        imported_count += 1
      else
        errors << "#{contact.full_name}: #{campaign_contact.errors.full_messages.join(', ')}"
      end
    end
    
    # Update campaign counts
    @campaign.update_counts!
    
    if imported_count > 0
      message = "Successfully imported #{imported_count} contact#{'s' unless imported_count == 1} from segment '#{segment.name}'"
      message += " (#{skipped_count} already added)" if skipped_count > 0
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  notice: message
    else
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: "No contacts found in segment '#{segment.name}'."
    end
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
            return lob_message
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
  
  def set_advertiser
    @advertiser = find_advertiser_by_slug(params[:advertiser_slug])
    
    unless @advertiser
      redirect_to advertisers_path, alert: 'Advertiser not found or you do not have access'
      return
    end
    
    set_current_advertiser(@advertiser)
  end
  
  def set_campaign
    @campaign = @advertiser.campaigns.find(params[:campaign_id])
  end
  
  def verify_campaign_editable!
    unless @campaign.editable?
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  alert: 'Cannot modify recipients after campaign has been sent.'
    end
  end
  
  def contact_params
    params.require(:campaign_contact).permit(
      :first_name, :last_name, :company,
      :address_line1, :address_line2, :address_city, 
      :address_state, :address_zip, :email, :phone
    )
  end
end

