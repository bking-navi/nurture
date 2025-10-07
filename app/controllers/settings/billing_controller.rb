# app/controllers/settings/billing_controller.rb
class Settings::BillingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :require_admin_access
  layout "sidebar"
  
  def index
    @balance = @advertiser.balance_dollars
    @transactions = @advertiser.balance_transactions.recent.page(params[:page]).per(50)
    @has_payment_method = @advertiser.payment_method_on_file?
    @settings = {
      low_balance_threshold: @advertiser.low_balance_threshold_dollars || 100,
      low_balance_emails_enabled: @advertiser.low_balance_emails_enabled.nil? ? true : @advertiser.low_balance_emails_enabled?,
      auto_recharge_enabled: @advertiser.auto_recharge_enabled.nil? ? false : @advertiser.auto_recharge_enabled?,
      auto_recharge_threshold: @advertiser.auto_recharge_threshold_dollars || 100,
      auto_recharge_amount: @advertiser.auto_recharge_amount_dollars || 100
    }
  end
  
  def new_deposit
    @publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key)
  end
  
  def create_deposit
    payment_intent_id = params[:payment_intent_id]
    
    # If we're confirming an existing PaymentIntent after bank verification
    if payment_intent_id.present?
      return confirm_payment_intent(payment_intent_id)
    end
    
    # Original payment flow
    amount_dollars = params[:amount].to_f
    amount_cents = (amount_dollars * 100).to_i
    payment_method_id = params[:payment_method_id]
    
    Rails.logger.info "=== CREATE DEPOSIT ==="
    Rails.logger.info "Amount: $#{amount_dollars} (#{amount_cents} cents)"
    Rails.logger.info "Payment Method ID: #{payment_method_id}"
    Rails.logger.info "Save Payment Method: #{params[:save_payment_method]}"
    
    if payment_method_id.blank?
      flash[:error] = "Payment method is required"
      redirect_to settings_new_deposit_path(@advertiser.slug) and return
    end
    
    if amount_cents < 500
      flash[:error] = "Minimum deposit is $5"
      redirect_to settings_new_deposit_path(@advertiser.slug) and return
    end
    
    if amount_cents > 1_000_000
      flash[:error] = "Maximum deposit is $10,000"
      redirect_to settings_new_deposit_path(@advertiser.slug) and return
    end
    
    service = StripePaymentService.new(@advertiser)
    
    begin
      intent = service.charge_and_add_funds(
        amount_cents,
        payment_method_id,
        current_user,
        auto_recharge: false
      )
      
      Rails.logger.info "Payment Intent created: #{intent.id} with status #{intent.status}"
      
      # Handle requires_action status (ACH bank verification)
      if intent.status == 'requires_action'
        # Return the client secret so the frontend can handle the next action
        respond_to do |format|
          format.html do
            # Store intent details in session for after redirect
            session[:pending_payment_intent] = {
              intent_id: intent.id,
              client_secret: intent.client_secret,
              amount: amount_dollars
            }
            # Redirect with client secret in URL
            redirect_to settings_billing_path(@advertiser.slug, payment_intent: intent.id, payment_intent_client_secret: intent.client_secret)
          end
          format.json { render json: { requires_action: true, client_secret: intent.client_secret, payment_intent_id: intent.id } }
        end
        return
      end
      
      # If this is their first payment method, save it
      if !@advertiser.payment_method_on_file? && params[:save_payment_method] == 'true'
        service.setup_payment_method(payment_method_id, current_user)
      end
      
      # Show different message based on payment status
      if intent.status == 'processing'
        flash[:notice] = "ACH payment of $#{'%.2f' % amount_dollars} initiated! Funds will be available in 1-4 business days."
      else
        flash[:notice] = "Successfully added $#{'%.2f' % amount_dollars} to your balance"
      end
      
      redirect_to settings_billing_path(@advertiser.slug)
    rescue StripePaymentService::PaymentError => e
      Rails.logger.error "Payment failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:error] = "Payment failed: #{e.message}"
      redirect_to settings_new_deposit_path(@advertiser.slug)
    rescue => e
      Rails.logger.error "Unexpected error in create_deposit: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:error] = "An unexpected error occurred: #{e.message}"
      redirect_to settings_new_deposit_path(@advertiser.slug)
    end
  end
  
  def update_settings
    settings_params = params.require(:billing_settings).permit(
      :low_balance_threshold_dollars,
      :low_balance_emails_enabled,
      :auto_recharge_enabled,
      :auto_recharge_threshold_dollars,
      :auto_recharge_amount_dollars
    )
    
    # Convert dollars to cents
    updates = {
      low_balance_threshold_cents: (settings_params[:low_balance_threshold_dollars].to_f * 100).to_i,
      low_balance_emails_enabled: settings_params[:low_balance_emails_enabled] == '1',
      auto_recharge_enabled: settings_params[:auto_recharge_enabled] == '1',
      auto_recharge_threshold_cents: (settings_params[:auto_recharge_threshold_dollars].to_f * 100).to_i,
      auto_recharge_amount_cents: (settings_params[:auto_recharge_amount_dollars].to_f * 100).to_i
    }
    
    # Validate auto-recharge requires payment method
    if updates[:auto_recharge_enabled] && !@advertiser.payment_method_on_file?
      flash[:error] = "Please add a payment method before enabling auto-recharge"
      redirect_to settings_billing_path(@advertiser.slug) and return
    end
    
    if @advertiser.update(updates)
      flash[:notice] = "Billing settings updated successfully"
    else
      flash[:error] = "Failed to update settings"
    end
    
    redirect_to settings_billing_path(@advertiser.slug)
  end
  
  private
  
  def confirm_payment_intent(payment_intent_id)
    Rails.logger.info "=== CONFIRMING PAYMENT INTENT ==="
    Rails.logger.info "Payment Intent ID: #{payment_intent_id}"
    
    begin
      intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
      Rails.logger.info "Payment Intent status: #{intent.status}"
      
      if intent.status == 'succeeded' || intent.status == 'processing'
        # Get payment method details
        payment_method = Stripe::PaymentMethod.retrieve(intent.payment_method)
        payment_method_type = payment_method.type
        
        last4 = if payment_method_type == 'card'
          payment_method.card.last4
        elsif payment_method_type == 'us_bank_account'
          payment_method.us_bank_account.last4
        else
          'N/A'
        end
        
        amount_cents = intent.amount
        amount_dollars = amount_cents / 100.0
        stripe_fee_cents = StripePaymentService.calculate_stripe_fee(amount_cents, payment_method_type)
        balance_before = @advertiser.balance_cents
        
        status = intent.status == 'processing' ? 'pending' : 'completed'
        
        # Update advertiser balance
        if status == 'pending'
          @advertiser.increment!(:pending_balance_cents, amount_cents)
          balance_after = balance_before
        else
          @advertiser.increment!(:balance_cents, amount_cents)
          balance_after = balance_before + amount_cents
        end
        
        # Create balance transaction
        transaction = @advertiser.balance_transactions.create!(
          transaction_type: 'deposit',
          amount_cents: amount_cents,
          balance_before_cents: balance_before,
          balance_after_cents: balance_after,
          description: "Added funds via #{payment_method_type == 'us_bank_account' ? 'ACH' : 'card'}",
          stripe_payment_intent_id: intent.id,
          stripe_charge_id: intent.charges.data.first&.id,
          payment_method_last4: last4,
          payment_method_type: payment_method_type,
          stripe_fee_cents: stripe_fee_cents,
          processed_by: current_user,
          status: status
        )
        
        Rails.logger.info "Balance transaction created: #{transaction.id}"
        
        message = if status == 'pending'
          "ACH payment of $#{'%.2f' % amount_dollars} initiated! Funds will be available in 1-4 business days."
        else
          "Successfully added $#{'%.2f' % amount_dollars} to your balance"
        end
        
        respond_to do |format|
          format.html do
            flash[:notice] = message
            redirect_to settings_billing_path(@advertiser.slug)
          end
          format.json { render json: { success: true, message: message, pending: status == 'pending' } }
        end
      else
        error_message = "Payment verification failed. Status: #{intent.status}"
        Rails.logger.error error_message
        
        respond_to do |format|
          format.html do
            flash[:error] = error_message
            redirect_to settings_billing_path(@advertiser.slug)
          end
          format.json { render json: { success: false, error: error_message }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "Error confirming payment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html do
          flash[:error] = "Failed to confirm payment: #{e.message}"
          redirect_to settings_billing_path(@advertiser.slug)
        end
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
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
  
  def require_admin_access
    unless current_user.admin_of?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), alert: 'You do not have permission to manage billing'
    end
  end
end

