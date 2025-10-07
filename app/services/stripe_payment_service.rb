# app/services/stripe_payment_service.rb
class StripePaymentService
  class PaymentError < StandardError; end
  
  def initialize(advertiser)
    @advertiser = advertiser
  end
  
  def charge_and_add_funds(amount_cents, payment_method_id, user, auto_recharge: false)
    raise ArgumentError, "Amount must be at least $5" if amount_cents < 500
    raise ArgumentError, "Amount must be at most $10,000" if amount_cents > 1_000_000
    
    # Create Stripe customer if needed
    @advertiser.create_stripe_customer!(user) unless @advertiser.stripe_customer_id
    
    # Calculate Stripe fee (we absorb it)
    stripe_fee = calculate_stripe_fee(amount_cents)
    total_to_charge = amount_cents + stripe_fee
    
    # Create payment intent
    intent = Stripe::PaymentIntent.create(
      amount: total_to_charge,  # Charge customer + fee
      currency: 'usd',
      customer: @advertiser.stripe_customer_id,
      payment_method: payment_method_id,
      off_session: true,
      confirm: true,
      description: auto_recharge ? 
        "Auto-recharge for #{@advertiser.name}" :
        "Balance top-up for #{@advertiser.name}",
      metadata: {
        advertiser_id: @advertiser.id,
        advertiser_name: @advertiser.name,
        user_id: user.id,
        user_email: user.email,
        balance_credit: amount_cents,  # The amount they get
        stripe_fee: stripe_fee,
        auto_recharge: auto_recharge
      }
    )
    
    # If successful, add funds to balance
    if intent.status == 'succeeded'
      # Get payment method details
      payment_method = Stripe::PaymentMethod.retrieve(payment_method_id)
      
      @advertiser.add_funds!(
        amount_cents,  # Credit the requested amount
        stripe_payment_intent_id: intent.id,
        processed_by: user,
        payment_method_last4: payment_method.card.last4,
        stripe_fee_cents: stripe_fee,
        auto_recharge: auto_recharge
      )
    end
    
    intent
  rescue Stripe::CardError => e
    raise PaymentError, e.message
  rescue Stripe::StripeError => e
    raise PaymentError, "Payment failed: #{e.message}"
  end
  
  def setup_payment_method(payment_method_id, user)
    # Ensure customer exists
    @advertiser.create_stripe_customer!(user) unless @advertiser.stripe_customer_id
    
    # Attach payment method to customer
    payment_method = Stripe::PaymentMethod.attach(
      payment_method_id,
      { customer: @advertiser.stripe_customer_id }
    )
    
    # Set as default payment method
    Stripe::Customer.update(
      @advertiser.stripe_customer_id,
      invoice_settings: {
        default_payment_method: payment_method_id
      }
    )
    
    # Store payment method details
    @advertiser.update!(
      payment_method_last4: payment_method.card.last4,
      payment_method_brand: payment_method.card.brand,
      payment_method_exp_month: payment_method.card.exp_month,
      payment_method_exp_year: payment_method.card.exp_year
    )
    
    payment_method
  rescue Stripe::StripeError => e
    raise PaymentError, "Failed to setup payment method: #{e.message}"
  end
  
  private
  
  def calculate_stripe_fee(amount_cents)
    # Stripe charges 2.9% + $0.30
    ((amount_cents * 0.029) + 30).ceil
  end
end

