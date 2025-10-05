# Lob.com API configuration
# Documentation: https://docs.lob.com/
#
# The Lob gem v6+ uses the Lob::Configuration object to set the API key
#
# Store keys in Rails credentials:
# rails credentials:edit
#   lob:
#     live_api_key: live_xxx
#     test_api_key: test_xxx

require 'lob'

# Configure Lob client with appropriate API key
api_key = if Rails.env.production?
  ENV['LOB_API_KEY'] || Rails.application.credentials.dig(:lob, :live_api_key)
elsif Rails.env.test?
  ENV['LOB_TEST_API_KEY'] || Rails.application.credentials.dig(:lob, :test_api_key)
else
  # Development uses test API key (no actual mail)
  ENV['LOB_TEST_API_KEY'] || Rails.application.credentials.dig(:lob, :test_api_key)
end

# Configure the Lob gem v6+
if api_key.present?
  # Set the default configuration
  Lob.configure do |config|
    config.username = api_key
  end
  
  mode = api_key.start_with?('test_') ? 'TEST' : 'LIVE'
  puts "✓ Lob configured with #{mode} API key (#{api_key[0..15]}...)"
  Rails.logger.info "Lob configured with #{mode} API key"
else
  puts "✗ WARNING: Lob API key not configured!"
  Rails.logger.warn "Lob API key not configured. Add credentials or set LOB_API_KEY / LOB_TEST_API_KEY environment variable."
end

