class Settings::AgenciesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :require_admin_access
  layout 'sidebar'
  
  def index
    @agency_accesses = @advertiser.advertiser_agency_accesses
                                  .includes(agency: [:users, :agency_memberships])
                                  .order(created_at: :desc)
  end
  
  def new
    # Form to invite agency
  end
  
  def create
    agency_owner_email = params[:agency_owner_email]
    
    # Find user by email
    agency_owner = User.find_by(email: agency_owner_email)
    
    unless agency_owner
      flash[:error] = "No user found with email #{agency_owner_email}"
      return render :new, status: :unprocessable_entity
    end
    
    # Find agency where user is owner
    agency = agency_owner.agencies
                         .joins(:agency_memberships)
                         .where(agency_memberships: { role: 'owner', user_id: agency_owner.id })
                         .first
    
    unless agency
      flash[:error] = "#{agency_owner_email} is not an agency owner"
      return render :new, status: :unprocessable_entity
    end
    
    # Check if already invited
    existing_access = @advertiser.advertiser_agency_accesses.find_by(agency: agency)
    is_reinvite = false
    
    if existing_access
      if existing_access.revoked?
        # Allow re-inviting a previously revoked agency
        existing_access.update!(
          status: 'pending',
          invited_at: Time.current,
          revoked_at: nil
        )
        access = existing_access
        is_reinvite = true
      else
        # Already has active invitation or access
        flash[:error] = "This agency already has #{existing_access.status} access"
        return render :new, status: :unprocessable_entity
      end
    else
      # Create new agency access invitation
      access = @advertiser.advertiser_agency_accesses.create!(
        agency: agency,
        status: 'pending',
        invited_at: Time.current
      )
    end
    
    # Send invitation email
    begin
      access.send_invitation_email
      message = is_reinvite ? "Re-invitation sent to #{agency.name}" : "Invitation sent to #{agency.name}"
      flash[:notice] = message
    rescue => e
      Rails.logger.error "Failed to send invitation email: #{e.message}"
      flash[:notice] = "Invitation created for #{agency.name}, but email failed to send"
    end
    
    redirect_to settings_agencies_path(@advertiser.slug)
  end
  
  def destroy
    access = @advertiser.advertiser_agency_accesses.find(params[:id])
    access.revoke!
    
    flash[:notice] = "Agency access revoked for #{access.agency.name}"
    redirect_to settings_agencies_path(@advertiser.slug)
  end
  
  private
  
  def set_advertiser
    @advertiser = current_user.advertisers.find_by(slug: params[:advertiser_slug])
    
    unless @advertiser
      flash[:error] = "Advertiser not found"
      redirect_to advertisers_path
      return
    end
    
    set_current_advertiser(@advertiser)
    @membership = current_user.advertiser_memberships.find_by(advertiser: @advertiser)
  end
  
  def require_admin_access
    unless @membership&.role&.in?(['owner', 'admin'])
      flash[:error] = "You don't have permission to manage agencies"
      redirect_to advertiser_dashboard_path(@advertiser.slug)
    end
  end
end

