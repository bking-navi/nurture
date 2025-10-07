class AgencyInvitationsController < ApplicationController
  before_action :authenticate_user!
  layout 'auth'
  
  def show
    @access = AdvertiserAgencyAccess.find_by_token_for(:invitation, params[:token])
    
    unless @access
      flash[:error] = "Invalid or expired invitation link"
      redirect_to root_path
      return
    end
    
    unless @access.pending?
      flash[:error] = "This invitation has already been #{@access.status}"
      redirect_to root_path
      return
    end
    
    # Check if current user has permission to accept
    @agency = @access.agency
    @advertiser = @access.advertiser
    @membership = current_user.agency_memberships.find_by(agency: @agency)
    
    unless @membership&.role&.in?(['owner', 'admin'])
      flash[:error] = "Only agency owners or admins can accept client invitations"
      redirect_to root_path
      return
    end
  end
  
  def accept
    @access = AdvertiserAgencyAccess.find_by_token_for(:invitation, params[:token])
    
    unless @access&.pending?
      flash[:error] = "Invalid or expired invitation"
      redirect_to root_path
      return
    end
    
    # Verify permission
    @agency = @access.agency
    membership = current_user.agency_memberships.find_by(agency: @agency)
    
    unless membership&.role&.in?(['owner', 'admin'])
      flash[:error] = "You don't have permission to accept this invitation"
      redirect_to root_path
      return
    end
    
    # Accept the invitation
    @access.accept!
    
    flash[:notice] = "You now have access to #{@access.advertiser.name}"
    
    # Redirect to agency dashboard (when it exists) or advertisers list for now
    if defined?(agency_dashboard_path)
      redirect_to agency_dashboard_path(@agency.slug)
    else
      redirect_to advertisers_path
    end
  end
end

