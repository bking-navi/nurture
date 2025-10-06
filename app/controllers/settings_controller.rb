class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  layout "sidebar"

  def index
    # Settings overview page
  end

  private

  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
    set_current_advertiser(@advertiser)
  end
end

