class Agencies::InvitationsController < ApplicationController
  before_action :set_invitation_by_token, only: [:accept, :process_acceptance]
  
  layout :resolve_layout

  def accept
    # Check if invitation is expired or not pending
    if @invitation.expired? || !@invitation.pending?
      render :invalid
      return
    end

    # If user is signed in, show simple acceptance page
    # If not signed in, show signup form
    @agency = @invitation.agency
    @existing_user = user_signed_in?
  end

  def process_acceptance
    # Check if invitation is expired or not pending
    if @invitation.expired? || !@invitation.pending?
      render :invalid
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

  private

  def accept_for_existing_user
    # Check if user's email matches invitation
    if current_user.email != @invitation.email
      flash[:error] = "This invitation was sent to #{@invitation.email}, but you're signed in as #{current_user.email}"
      redirect_to accept_agency_team_invitation_path(@invitation.token)
      return
    end

    # Accept the invitation
    membership = @invitation.accept!(current_user)
    
    if membership
      flash[:notice] = "Welcome to #{@invitation.agency.name}!"
      redirect_to agency_dashboard_path(@invitation.agency.slug)
    else
      flash[:error] = "Unable to accept invitation. Please try again."
      redirect_to accept_agency_team_invitation_path(@invitation.token)
    end
  end

  def accept_for_new_user
    # Create new user account
    user_params = params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
    
    # Verify email matches invitation
    unless user_params[:email] == @invitation.email
      flash.now[:error] = "Email must match the invitation email: #{@invitation.email}"
      @agency = @invitation.agency
      @existing_user = false
      return render :accept, status: :unprocessable_entity
    end
    
    @user = User.new(user_params)
    @user.email_verified = true # Auto-verify since they have invitation token
    @user.email_verified_at = Time.current
    
    if @user.save
      # Accept invitation
      membership = @invitation.accept!(@user)
      
      if membership
        # Sign in the new user
        sign_in(@user)
        
        flash[:notice] = "Account created! Welcome to #{@invitation.agency.name}"
        redirect_to agency_dashboard_path(@invitation.agency.slug)
      else
        flash[:error] = "Account created but unable to complete invitation acceptance"
        redirect_to root_path
      end
    else
      flash.now[:error] = "Unable to create account"
      @agency = @invitation.agency
      @existing_user = false
      render :accept, status: :unprocessable_entity
    end
  end

  def set_invitation_by_token
    @invitation = AgencyInvitation.find_by(token: params[:token])
    
    unless @invitation
      flash[:error] = "Invalid or expired invitation link"
      redirect_to root_path
    end
  end
  
  def resolve_layout
    user_signed_in? ? 'application' : 'auth'
  end
end

