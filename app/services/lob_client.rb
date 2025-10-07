class LobClient
  class << self
    # Get configured API client
    def api_client
      @api_client ||= begin
        config = Lob::Configuration.default
        Lob::ApiClient.new(config)
      end
    end
    
    # Log API call wrapper
    def log_api_call(advertiser:, campaign: nil, endpoint:, method:, request_body: nil)
      start_time = Time.current
      start_ms = (start_time.to_f * 1000).to_i
      
      begin
        result = yield
        
        end_time = Time.current
        end_ms = (end_time.to_f * 1000).to_i
        duration_ms = end_ms - start_ms
        
        # Extract Lob object details from response
        lob_object_id = result.try(:id)
        lob_object_type = result.try(:object) || detect_object_type(endpoint)
        
        # Estimate cost (Lob charges per postcard sent)
        cost_cents = case lob_object_type
        when 'postcard'
          105 # $1.05 per postcard (will be adjusted based on actual pricing)
        else
          0
        end
        
        LobApiLog.create!(
          advertiser: advertiser,
          campaign: campaign,
          endpoint: endpoint,
          method: method,
          request_body: sanitize_request(request_body),
          response_body: sanitize_response(result),
          status_code: 200,
          success: true,
          duration_ms: duration_ms,
          cost_cents: cost_cents,
          lob_object_id: lob_object_id,
          lob_object_type: lob_object_type
        )
        
        result
      rescue => e
        end_time = Time.current
        end_ms = (end_time.to_f * 1000).to_i
        duration_ms = end_ms - start_ms
        
        status_code = e.respond_to?(:code) ? e.code : 500
        
        LobApiLog.create!(
          advertiser: advertiser,
          campaign: campaign,
          endpoint: endpoint,
          method: method,
          request_body: sanitize_request(request_body),
          response_body: nil,
          status_code: status_code,
          success: false,
          error_message: e.message,
          duration_ms: duration_ms,
          cost_cents: 0,
          lob_object_type: detect_object_type(endpoint)
        )
        
        raise e
      end
    end
    
    def detect_object_type(endpoint)
      case endpoint
      when /postcards/
        'postcard'
      when /verifications/
        'verification'
      when /addresses/
        'address'
      else
        'other'
      end
    end
    
    def sanitize_request(data)
      return nil unless data
      hash = data.try(:to_hash) || data
      
      # Remove PII from request data
      if hash.is_a?(Hash)
        sanitized = hash.deep_dup
        # Remove address details
        if sanitized[:to].is_a?(Hash)
          sanitized[:to] = {
            name: '[REDACTED]',
            address_city: sanitized[:to][:address_city],
            address_state: sanitized[:to][:address_state],
            address_zip: sanitized[:to][:address_zip]&.first(3) # Only first 3 digits
          }
        end
        # Remove from address
        if sanitized[:from].is_a?(Hash)
          sanitized[:from] = '[REDACTED]'
        end
        # Don't store HTML/PDF content
        sanitized.delete(:front)
        sanitized.delete(:back)
        sanitized.delete(:merge_variables)
        sanitized
      else
        nil
      end
    end
    
    def sanitize_response(result)
      return nil unless result
      # Only store essential fields, no PII
      if result.respond_to?(:to_hash)
        hash = result.to_hash
        {
          id: hash[:id],
          object: hash[:object],
          status: hash[:status],
          expected_delivery_date: hash[:expected_delivery_date],
          send_date: hash[:send_date]
        }.compact
      else
        nil
      end
    end
    
    # Create a postcard via Lob API
    def create_postcard(campaign_contact:, campaign:, from_address:)
      postcards_api = Lob::PostcardsApi.new(api_client)
      
      # Determine front and back content (PDF URLs or HTML)
      # Use helper methods that check both creative library and direct uploads
      front_pdf = campaign.front_pdf_file
      back_pdf = campaign.back_pdf_file
      
      if front_pdf&.attached? && back_pdf&.attached?
        # Use PDF files - generate publicly accessible URLs
        host_url = ENV['APP_URL'] || ENV['NGROK_URL'] || 'http://localhost:3000'
        
        # Check if we're using localhost (which Lob can't access)
        if Rails.env.development? && host_url.include?('localhost')
          raise "PDF uploads require a publicly accessible URL. Please either:\n" \
                "1. Set up ngrok: `ngrok http 3000` and set NGROK_URL=https://your-ngrok-url.ngrok-free.app\n" \
                "2. Deploy to production and use PDFs there\n" \
                "3. Use HTML templates for local testing instead"
        end
        
        front_content = Rails.application.routes.url_helpers.rails_blob_url(
          front_pdf,
          host: host_url
        )
        back_content = Rails.application.routes.url_helpers.rails_blob_url(
          back_pdf,
          host: host_url
        )
      else
        # Use HTML templates
        # Build contact-specific data for template rendering
        contact_data = {
          first_name: campaign_contact.first_name,
          last_name: campaign_contact.last_name,
          full_name: campaign_contact.full_name,
          company: campaign_contact.company,
          email: campaign_contact.email,
          phone: campaign_contact.phone
        }
        
        # Render HTML using campaign templates or fallback to simple messages
        front_content = if campaign.using_template?
          campaign.render_front_html(contact_data)
        else
          "<html><body><h1>#{campaign.front_message || 'Hello!'}</h1></body></html>"
        end
        
        back_content = if campaign.using_template?
          campaign.render_back_html(contact_data)
        else
          "<html><body><p>#{campaign.back_message || 'Thank you!'}</p></body></html>"
        end
      end
      
      postcard_editable = Lob::PostcardEditable.new(
        description: "Campaign: #{campaign.name} - #{campaign_contact.full_name}",
        to: format_address_editable(
          name: campaign_contact.full_name,
          company: campaign_contact.company,
          address_line1: campaign_contact.address_line1,
          address_line2: campaign_contact.address_line2,
          address_city: campaign_contact.address_city,
          address_state: campaign_contact.address_state,
          address_zip: campaign_contact.address_zip,
          address_country: campaign_contact.address_country
        ),
        from: from_address,
        front: front_content,
        back: back_content,
        merge_variables: build_merge_variables(campaign, campaign_contact),
        size: "6x9",
        mail_type: "usps_first_class",
        use_type: "marketing",
        metadata: {
          campaign_id: campaign.id.to_s,
          campaign_contact_id: campaign_contact.id.to_s,
          advertiser_id: campaign.advertiser_id.to_s
        }
      )
      
      log_api_call(
        advertiser: campaign.advertiser,
        campaign: campaign,
        endpoint: '/v1/postcards',
        method: 'POST',
        request_body: postcard_editable
      ) do
        postcards_api.create(postcard_editable)
      end
    end
    
    # Retrieve postcard status
    def get_postcard(lob_postcard_id)
      postcards_api = Lob::PostcardsApi.new(api_client)
      postcards_api.get(lob_postcard_id)
    end
    
    # List available templates
    def list_templates(limit: 50)
      templates_api = Lob::TemplatesApi.new(api_client)
      templates_api.list(limit: limit)
    end
    
    # Verify a US address
    def verify_address(address_line1:, city:, state:, zip:, address_line2: nil, advertiser: nil, campaign: nil)
      us_verifications_api = Lob::UsVerificationsApi.new(api_client)
      
      verification_data = Lob::UsVerificationsWritable.new(
        primary_line: address_line1,
        secondary_line: address_line2,
        city: city,
        state: state,
        zip_code: zip
      )
      
      if advertiser
        log_api_call(
          advertiser: advertiser,
          campaign: campaign,
          endpoint: '/v1/us_verifications',
          method: 'POST',
          request_body: verification_data
        ) do
          us_verifications_api.verify(verification_data)
        end
      else
        # No logging if advertiser context not provided
        us_verifications_api.verify(verification_data)
      end
    end
    
    # Format address for Lob API v6+ (returns AddressEditable object)
    def format_address_editable(name:, address_line1:, address_city:, address_state:, address_zip:, 
                                company: nil, address_line2: nil, address_country: 'US')
      Lob::AddressEditable.new(
        name: name,
        company: company,
        address_line1: address_line1,
        address_line2: address_line2,
        address_city: address_city,
        address_state: address_state,
        address_zip: address_zip,
        address_country: address_country
      )
    end
    
    # Format address hash for Lob API (legacy, returns hash)
    def format_address(name:, address_line1:, address_city:, address_state:, address_zip:, 
                       company: nil, address_line2: nil, address_country: 'US')
      {
        name: name,
        company: company,
        address_line1: address_line1,
        address_line2: address_line2,
        address_city: address_city,
        address_state: address_state,
        address_zip: address_zip,
        address_country: address_country
      }.compact # Remove nil values
    end
    
    # Build merge variables for template
    def build_merge_variables(campaign, campaign_contact)
      base_vars = campaign.merge_variables || {}
      
      # Add recipient-specific variables
      base_vars.merge(
        first_name: campaign_contact.first_name,
        last_name: campaign_contact.last_name,
        full_name: campaign_contact.full_name,
        company: campaign_contact.company
      ).compact
    end
  end
end

