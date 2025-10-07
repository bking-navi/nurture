# config/initializers/stripe.rb
Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
Stripe.api_version = '2024-12-18.acacia'  # Use latest stable version

# Set app info for Stripe dashboard
Stripe.set_app_info(
  'Nurture',
  version: '1.0.0',
  url: 'https://nurture.com'
)

