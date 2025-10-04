class Users::SessionsController < Devise::SessionsController
  # GET /resource/sign_in
  def new
    # Store invitation token if provided
    session[:invitation_token] = params[:invitation_token] if params[:invitation_token].present?
    super
  end

  # POST /resource/sign_in
  def create
    super do |resource|
      # Check if there's a pending invitation token
      if session[:invitation_token].present?
        invitation_token = session.delete(:invitation_token)
        # Redirect to invitation acceptance after successful sign in
        return redirect_to accept_invitation_path(token: invitation_token)
      end
    end
  end
end

