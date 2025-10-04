class InvitationsController < ApplicationController
  before_action :authenticate_user!, except: [:accept, :process_acceptance]
  before_action :set_advertiser, except: [:accept, :process_acceptance]
  before_action :authorize_team_management!, except: [:accept, :process_acceptance]
  before_action :set_invitation_by_token, only: [:accept, :process_acceptance]

  def accept
    # Check if invitation is expired
    if @invitation.expired?
      redirect_to root_path, alert: "This invitation has expired. Please contact the team owner for a new invitation."
      return
    end

    # Check if invitation is already accepted
    unless @invitation.pending?
      redirect_to root_path, alert: "This invitation has already been used."
      return
    end

    # If user is signed in, show simple acceptance page
    # If not signed in, show signup form
    @advertiser = @invitation.advertiser
    @existing_user = user_signed_in?
  end

  def process_acceptance
    # Check if invitation is expired or already accepted
    if @invitation.expired?
      redirect_to root_path, alert: "This invitation has expired."
      return
    end

    unless @invitation.pending?
      redirect_to root_path, alert: "This invitation has already been used."
      return
    end

    if user_signed_in?
      # Existing user accepting invitation
      accept_for_existing_user
    else
      # New user signing up from invitation
      accept_for_new_user
    end
  end

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
    current_user.advertiser_memberships.reset
    
    @advertiser = current_user.advertisers.find_by(slug: params[:advertiser_slug])
    
    unless @advertiser
      redirect_to advertisers_path
      return
    end
  end

  def set_invitation_by_token
    @invitation = Invitation.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Invalid invitation link."
  end

  def authorize_team_management!
    unless current_user.can_manage_team?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), alert: "You don't have permission to manage team members"
    end
  end

  def accept_for_existing_user
    # Accept invitation for the current user
    begin
      @invitation.accept!(current_user)
      redirect_to advertiser_dashboard_path(@invitation.advertiser.slug), 
                  notice: "Welcome to #{@invitation.advertiser.name}! You've been added as a #{@invitation.role}."
    rescue => e
      Rails.logger.error "Failed to accept invitation: #{e.message}"
      redirect_to root_path, alert: "Failed to accept invitation. Please try again."
    end
  end

  def accept_for_new_user
    # Check if user already exists with this email
    existing_user = User.find_by(email: @invitation.email)
    
    if existing_user
      # User exists but is not signed in - redirect to sign in
      session[:invitation_token] = @invitation.token
      redirect_to new_user_session_path, alert: "An account with this email already exists. Please sign in to accept the invitation."
      return
    end
    
    # Create new user from invitation
    user_params = params.require(:user).permit(:first_name, :last_name, :password, :password_confirmation)
    
    # Create user with invitation email
    @user = User.new(
      email: @invitation.email,
      first_name: user_params[:first_name],
      last_name: user_params[:last_name],
      password: user_params[:password],
      password_confirmation: user_params[:password_confirmation]
    )

    # Skip email confirmation for invited users
    @user.skip_confirmation!

    if @user.save
      # Accept the invitation
      @invitation.accept!(@user)
      
      # Sign in the new user
      sign_in(@user)
      
      redirect_to advertiser_dashboard_path(@invitation.advertiser.slug),
                  notice: "Welcome to #{@invitation.advertiser.name}! Your account has been created."
    else
      @advertiser = @invitation.advertiser
      @existing_user = false
      render :accept, status: :unprocessable_entity
    end
  end

  def invitation_params
    params.require(:invitation).permit(:email, :role)
  end
end
