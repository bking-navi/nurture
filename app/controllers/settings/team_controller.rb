class Settings::TeamController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :authorize_team_access!
  before_action :authorize_team_management!, only: [:update_role, :remove_member]
  
  layout "sidebar"

  def index
    @members = @advertiser.advertiser_memberships.includes(:user).order(created_at: :asc)
    @pending_invitations = @advertiser.invitations.active.order(created_at: :desc)
    @can_manage_team = current_user.can_manage_team?(@advertiser)
  end

  def update_role
    @member = @advertiser.advertiser_memberships.find(params[:id])
    new_role = params[:role]

    # Validation: Can't change your own role
    if @member.user == current_user
      redirect_to settings_team_path(@advertiser.slug), alert: "You cannot change your own role"
      return
    end

    # Validation: Cannot change to or from owner role
    if new_role == 'owner' || @member.role == 'owner'
      redirect_to settings_team_path(@advertiser.slug), alert: "Owner role cannot be changed"
      return
    end

    # Validation: Admins can only manage non-admin roles
    if @membership.role == 'admin' && @member.role == 'admin'
      redirect_to settings_team_path(@advertiser.slug), alert: "You don't have permission to change this member's role"
      return
    end

    @member.update!(role: new_role)
    redirect_to settings_team_path(@advertiser.slug), notice: "#{@member.user.display_name}'s role changed to #{new_role}"
  end

  def remove_member
    @member = @advertiser.advertiser_memberships.find(params[:id])

    # Validation: Can't remove yourself
    if @member.user == current_user
      redirect_to settings_team_path(@advertiser.slug), alert: "You cannot remove yourself from the team"
      return
    end

    # Validation: Can't remove owner
    if @member.role == 'owner'
      redirect_to settings_team_path(@advertiser.slug), alert: "Cannot remove the owner. Transfer ownership first."
      return
    end

    # Validation: Admins cannot remove other admins or owner
    if @membership.role == 'admin' && @member.role.in?(['owner', 'admin'])
      redirect_to settings_team_path(@advertiser.slug), alert: "You don't have permission to remove this member"
      return
    end

    user_name = @member.user.display_name
    @member.destroy
    redirect_to settings_team_path(@advertiser.slug), notice: "#{user_name} has been removed from the team"
  end

  private

  def set_advertiser
    # Reload associations to avoid any caching issues
    current_user.advertiser_memberships.reset
    
    @advertiser = current_user.advertisers.find_by(slug: params[:advertiser_slug])
    
    unless @advertiser
      redirect_to advertisers_path
      return
    end
    
    # Set current advertiser context for automatic scoping
    set_current_advertiser(@advertiser)
    
    @membership = current_user.advertiser_memberships.where(advertiser: @advertiser).first!
  end

  def authorize_team_access!
    unless current_user.has_access_to?(@advertiser)
      redirect_to root_path, alert: "You don't have access to this advertiser"
    end
  end

  def authorize_team_management!
    unless current_user.can_manage_team?(@advertiser)
      redirect_to settings_team_path(@advertiser.slug), alert: "You don't have permission to manage team members"
    end
  end
end
