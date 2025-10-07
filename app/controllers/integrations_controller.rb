class IntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  layout "sidebar"

  def index
    @shopify_stores = @advertiser.shopify_stores
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
end

