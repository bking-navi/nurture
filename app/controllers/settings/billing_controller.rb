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
    amount_dollars = params[:amount].to_f
    amount_cents = (amount_dollars * 100).to_i
    payment_method_id = params[:payment_method_id]
    
    if amount_cents < 500
      flash[:error] = "Minimum deposit is $5"
      redirect_to new_deposit_path(@advertiser.slug) and return
    end
    
    if amount_cents > 1_000_000
      flash[:error] = "Maximum deposit is $10,000"
      redirect_to new_deposit_path(@advertiser.slug) and return
    end
    
    service = StripePaymentService.new(@advertiser)
    
    begin
      intent = service.charge_and_add_funds(
        amount_cents,
        payment_method_id,
        current_user,
        auto_recharge: false
      )
      
      # If this is their first payment method, save it
      if !@advertiser.payment_method_on_file? && params[:save_payment_method] == 'true'
        service.setup_payment_method(payment_method_id, current_user)
      end
      
      flash[:notice] = "Successfully added $#{'%.2f' % amount_dollars} to your balance"
      redirect_to settings_billing_path(@advertiser.slug)
    rescue StripePaymentService::PaymentError => e
      flash[:error] = "Payment failed: #{e.message}"
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

