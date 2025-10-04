class InvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :authorize_team_management!

  def new
    @invitation = @advertiser.invitations.new
  end

  def create
    @invitation = @advertiser.invitations.new(invitation_params)
    @invitation.invited_by = current_user

    if @invitation.save
      # Send invitation email
      begin
        @invitation.send_invitation_email
        redirect_to advertiser_team_path(@advertiser.slug), notice: "Invitation sent to #{@invitation.email}"
      rescue => e
        Rails.logger.error "Failed to send invitation email: #{e.message}"
        redirect_to advertiser_team_path(@advertiser.slug), alert: "Invitation created but email failed to send. Please try resending."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend
    @invitation = @advertiser.invitations.find(params[:id])
    
    if @invitation.resend!
      redirect_to advertiser_team_path(@advertiser.slug), notice: "Invitation resent to #{@invitation.email}"
    else
      redirect_to advertiser_team_path(@advertiser.slug), alert: "Failed to resend invitation"
    end
  end

  def destroy
    @invitation = @advertiser.invitations.find(params[:id])
    @invitation.destroy
    
    redirect_to advertiser_team_path(@advertiser.slug), notice: "Invitation cancelled"
  end

  private

  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end

  def authorize_team_management!
    unless current_user.can_manage_team?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), alert: "You don't have permission to manage team members"
    end
  end

  def invitation_params
    params.require(:invitation).permit(:email, :role)
  end
end
