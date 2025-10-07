# app/controllers/settings/payment_methods_controller.rb
class Settings::PaymentMethodsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :require_admin_access
  layout "sidebar"
  
  def edit
    @publishable_key = Rails.application.credentials.dig(:stripe, :publishable_key)
    @current_payment_method = @advertiser.payment_method_summary
  end
  
  def update
    payment_method_id = params[:payment_method_id]
    
    service = StripePaymentService.new(@advertiser)
    
    begin
      service.setup_payment_method(payment_method_id, current_user)
      
      flash[:notice] = "Payment method updated successfully"
      redirect_to settings_billing_path(@advertiser.slug)
    rescue StripePaymentService::PaymentError => e
      flash[:error] = "Failed to update payment method: #{e.message}"
      redirect_to settings_edit_payment_method_path(@advertiser.slug)
    end
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

