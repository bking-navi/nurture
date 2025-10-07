# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:stripe]
  
  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)
    
    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, endpoint_secret
      )
    rescue JSON::ParserError => e
      # Invalid payload
      render json: { error: 'Invalid payload' }, status: 400 and return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      render json: { error: 'Invalid signature' }, status: 400 and return
    end
    
    # Handle the event
    case event.type
    when 'payment_intent.succeeded'
      handle_payment_succeeded(event.data.object)
    when 'payment_intent.payment_failed'
      handle_payment_failed(event.data.object)
    when 'customer.updated'
      handle_customer_updated(event.data.object)
    else
      Rails.logger.info "Unhandled Stripe event type: #{event.type}"
    end
    
    render json: { message: 'Success' }, status: 200
  end
  
  private
  
  def handle_payment_succeeded(payment_intent)
    # Log success
    Rails.logger.info "Payment succeeded: #{payment_intent.id}"
    
    # The payment was already processed in StripePaymentService when it was confirmed
    # This is just a confirmation webhook
  end
  
  def handle_payment_failed(payment_intent)
    Rails.logger.error "Payment failed: #{payment_intent.id} - #{payment_intent.last_payment_error&.message}"
    
    # Find advertiser
    advertiser_id = payment_intent.metadata&.advertiser_id
    return unless advertiser_id
    
    advertiser = Advertiser.find_by(id: advertiser_id)
    return unless advertiser
    
    # Send notification email to owner
    if advertiser.owner
      # You could create a separate mailer for this if needed
      Rails.logger.info "Sending payment failure notification to #{advertiser.owner.email}"
    end
  end
  
  def handle_customer_updated(customer)
    # Update advertiser's payment method info if it changed
    advertiser = Advertiser.find_by(stripe_customer_id: customer.id)
    return unless advertiser
    
    # If default payment method changed, update our records
    if customer.invoice_settings&.default_payment_method
      begin
        pm = Stripe::PaymentMethod.retrieve(customer.invoice_settings.default_payment_method)
        
        advertiser.update(
          payment_method_last4: pm.card.last4,
          payment_method_brand: pm.card.brand,
          payment_method_exp_month: pm.card.exp_month,
          payment_method_exp_year: pm.card.exp_year
        )
      rescue Stripe::StripeError => e
        Rails.logger.error "Failed to retrieve payment method: #{e.message}"
      end
    end
  end
end

