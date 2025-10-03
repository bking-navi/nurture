class LoopsClient
  include HTTParty
  
  base_uri 'https://app.loops.so/api/v1'
  
  def initialize
    # Try ENV first, then fall back to credentials
    @api_key = ENV['LOOPS_API_KEY'] || Rails.application.credentials.dig(:loops, :api_key)
    raise "Loops API key not configured" unless @api_key
  end
  
  def send_transactional_email(email:, template_id:, variables: {})
    response = self.class.post(
      '/transactional',
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        email: email,
        transactionalId: template_id,
        dataVariables: variables
      }.to_json
    )
    
    if response.success?
      Rails.logger.info "Loops email sent successfully to #{email}"
      response.parsed_response
    else
      Rails.logger.error "Loops email failed: #{response.body}"
      raise "Failed to send email: #{response.body}"
    end
  end
  
  def create_or_update_contact(email:, properties: {})
    response = self.class.post(
      '/contacts/create',
      headers: {
        'Authorization' => "Bearer #{@api_key}",
        'Content-Type' => 'application/json'
      },
      body: {
        email: email,
        properties: properties
      }.to_json
    )
    
    if response.success?
      Rails.logger.info "Loops contact created/updated: #{email}"
      response.parsed_response
    else
      Rails.logger.error "Loops contact creation failed: #{response.body}"
      raise "Failed to create/update contact: #{response.body}"
    end
  end
end
