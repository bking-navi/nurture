class LobClient
  class << self
    # Get configured API client
    def api_client
      @api_client ||= begin
        config = Lob::Configuration.default
        Lob::ApiClient.new(config)
      end
    end
    
    # Create a postcard via Lob API
    def create_postcard(campaign_contact:, campaign:, from_address:)
      postcards_api = Lob::PostcardsApi.new(api_client)
      
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
        front: "<html><body><h1>#{campaign.front_message || 'Hello!'}</h1></body></html>",
        back: "<html><body><p>#{campaign.back_message || 'Thank you!'}</p></body></html>",
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
      
      postcards_api.create(postcard_editable)
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
    def verify_address(address_line1:, city:, state:, zip:, address_line2: nil)
      us_verifications_api = Lob::UsVerificationsApi.new(api_client)
      
      verification_data = Lob::UsVerificationsWritable.new(
        primary_line: address_line1,
        secondary_line: address_line2,
        city: city,
        state: state,
        zip_code: zip
      )
      
      us_verifications_api.verify(verification_data)
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

