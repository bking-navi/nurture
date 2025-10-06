class IntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  layout "sidebar"

  def index
    @shopify_stores = @advertiser.shopify_stores
  end

  private

  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end
end

