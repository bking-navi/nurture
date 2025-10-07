# app/services/stripe_payment_service.rb
class StripePaymentService
  class PaymentError < StandardError; end
  
  def initialize(advertiser)
    @advertiser = advertiser
  end
  
  def charge_and_add_funds(amount_cents, payment_method_id, user, auto_recharge: false)
    # Get payment method details to determine type
    payment_method = Stripe::PaymentMethod.retrieve(payment_method_id)
    payment_method_type = payment_method.type
    
    # Validate amounts based on payment method
    if payment_method_type == 'us_bank_account'
      raise ArgumentError, "ACH minimum is $100" if amount_cents < 10_000
      raise ArgumentError, "ACH maximum is $10,000" if amount_cents > 1_000_000
    else
      raise ArgumentError, "Card minimum is $5" if amount_cents < 500
      raise ArgumentError, "Card maximum is $10,000" if amount_cents > 1_000_000
    end
    
    # Create Stripe customer if needed
    @advertiser.create_stripe_customer!(user) unless @advertiser.stripe_customer_id
    
    # Calculate Stripe fee (we absorb it)
    stripe_fee = calculate_stripe_fee(amount_cents, payment_method_type)
    total_to_charge = amount_cents + stripe_fee
    
    # Create payment intent
    intent_params = {
      amount: total_to_charge,  # Charge customer + fee
      currency: 'usd',
      customer: @advertiser.stripe_customer_id,
      payment_method: payment_method_id,
      payment_method_types: [payment_method_type], # Explicitly allow the payment method type
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
        auto_recharge: auto_recharge,
        payment_method_type: payment_method_type
      }
    }
    
    # ACH requires manual confirmation and return_url for redirect-based authentication
    if payment_method_type == 'us_bank_account'
      intent_params[:confirm] = true
      intent_params[:return_url] = "#{ENV.fetch('APP_HOST', 'http://localhost:3000')}/advertisers/#{@advertiser.slug}/settings/billing"
      intent_params[:mandate_data] = {
        customer_acceptance: {
          type: 'online',
          online: {
            ip_address: '0.0.0.0',  # In production, pass real IP
            user_agent: 'Nurture'
          }
        }
      }
    else
      intent_params[:off_session] = true
      intent_params[:confirm] = true
    end
    
    intent = Stripe::PaymentIntent.create(intent_params)
    
    # Handle payment based on status
    # Card payments: 'succeeded' immediately
    # ACH payments: 'processing' initially, 'succeeded' later via webhook
    # ACH with verification: 'requires_action' for Financial Connections flow
    if intent.status == 'requires_action'
      # ACH requires additional action (bank verification via Plaid/Financial Connections)
      # Return the intent so the client can handle next action
      return intent
    elsif intent.status == 'succeeded'
      # Card payment succeeded immediately
      last4 = payment_method.type == 'card' ? payment_method.card.last4 : payment_method.us_bank_account.last4
      
      @advertiser.add_funds!(
        amount_cents,
        stripe_payment_intent_id: intent.id,
        processed_by: user,
        payment_method_last4: last4,
        stripe_fee_cents: stripe_fee,
        auto_recharge: auto_recharge,
        payment_method_type: payment_method_type,
        status: 'completed'
      )
    elsif intent.status == 'processing' && payment_method_type == 'us_bank_account'
      # ACH payment initiated, will complete later via webhook
      last4 = payment_method.us_bank_account.last4
      
      @advertiser.add_funds!(
        amount_cents,
        stripe_payment_intent_id: intent.id,
        processed_by: user,
        payment_method_last4: last4,
        stripe_fee_cents: stripe_fee,
        auto_recharge: auto_recharge,
        payment_method_type: payment_method_type,
        status: 'pending'
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
  
  def calculate_stripe_fee(amount_cents, payment_method_type = 'card')
    if payment_method_type == 'us_bank_account'
      # ACH: 0.8% capped at $5.00
      fee = (amount_cents * 0.008).ceil
      [fee, 500].min  # Cap at $5.00
    else
      # Card: 2.9% + $0.30
      ((amount_cents * 0.029) + 30).ceil
    end
  end
end

