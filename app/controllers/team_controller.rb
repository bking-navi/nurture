class TeamController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :authorize_team_access!

  def index
    @members = @advertiser.advertiser_memberships.includes(:user).order(created_at: :asc)
    @pending_invitations = @advertiser.invitations.active.order(created_at: :desc)
    @can_manage_team = current_user.can_manage_team?(@advertiser)
  end

  private

  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
    @membership = current_user.advertiser_memberships.find_by(advertiser: @advertiser)
  end

  def authorize_team_access!
    unless current_user.has_access_to?(@advertiser)
      redirect_to root_path, alert: "You don't have access to this advertiser"
    end
  end
end
