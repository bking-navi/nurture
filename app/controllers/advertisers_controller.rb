class AdvertisersController < ApplicationController
  before_action :authenticate_user!

  def new
    @advertiser = Advertiser.new
  end

  def create
    @advertiser = Advertiser.new(advertiser_params)
    
    if @advertiser.save
      # Create owner membership for current user
      @advertiser.advertiser_memberships.create!(
        user: current_user,
        role: 'owner',
        status: 'accepted'
      )
      
      redirect_to advertiser_dashboard_path(@advertiser.slug), notice: "#{@advertiser.name} has been created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @advertiser = current_user.advertisers.find_by!(slug: params[:slug])
    @membership = current_user.advertiser_memberships.find_by(advertiser: @advertiser)
  end

  private

  def advertiser_params
    params.require(:advertiser).permit(
      :name,
      :street_address,
      :city,
      :state,
      :postal_code,
      :country,
      :website_url
    )
  end
end
