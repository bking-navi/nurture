class AdvertisersController < ApplicationController
  before_action :authenticate_user!
  layout "auth", only: [:new, :create]
  layout "sidebar", only: [:show]

  def index
    # Get advertisers from direct membership
    direct_advertisers = current_user.advertisers.includes(:advertiser_memberships)
    
    # Get advertisers from agency client assignments
    agency_advertisers = Advertiser.joins(advertiser_agency_accesses: { agency_client_assignments: :agency_membership })
                                   .where(advertiser_agency_accesses: { status: 'accepted' })
                                   .where(agency_client_assignments: { agency_membership: current_user.agency_memberships.accepted })
                                   .distinct
    
    @advertisers = (direct_advertisers + agency_advertisers).uniq.sort_by(&:name)
  end

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
    # Reset associations to avoid caching issues
    current_user.advertiser_memberships.reset
    
    # First, try to find advertiser through direct membership
    @advertiser = current_user.advertisers.find_by(slug: params[:slug])
    @membership = current_user.advertiser_memberships.find_by(advertiser: @advertiser) if @advertiser
    
    # If not found, check agency access
    unless @advertiser
      @advertiser = Advertiser.joins(advertiser_agency_accesses: { agency_client_assignments: :agency_membership })
                              .where(advertisers: { slug: params[:slug] })
                              .where(advertiser_agency_accesses: { status: 'accepted' })
                              .where(agency_client_assignments: { agency_membership: current_user.agency_memberships.accepted })
                              .first
      
      if @advertiser
        # User is accessing via agency - find which agency and assignment
        @agency_assignment = AgencyClientAssignment.joins(:agency_membership, :advertiser_agency_access)
                                                   .where(agency_memberships: { user: current_user })
                                                   .where(advertiser_agency_accesses: { advertiser: @advertiser, status: 'accepted' })
                                                   .first
      end
    end
    
    unless @advertiser
      redirect_to advertisers_path
      return
    end
    
    # Set current advertiser context for automatic scoping
    set_current_advertiser(@advertiser)
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
