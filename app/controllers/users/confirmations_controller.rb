class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    yield resource if block_given?

    if resource.errors.empty?
      # Mark email as verified
      resource.update!(email_verified: true, email_verified_at: Time.current)
      
      set_flash_message!(:notice, :confirmed)
      respond_with_navigational(resource) { redirect_to after_confirmation_path_for(resource_name, resource) }
    else
      # Check if the error is because email was already confirmed
      if resource.errors.of_kind?(:email, :already_confirmed)
        # Email already confirmed - just redirect them to sign in or advertiser setup
        set_flash_message!(:notice, :already_confirmed)
        redirect_to new_user_session_path
      else
        respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
      end
    end
  end

  # POST /resource/confirmation
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      respond_with({}, location: after_resending_confirmation_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  end

  protected

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    # Redirect to advertiser creation after email verification
    new_advertiser_path
  end

  # The path used after resending confirmation instructions.
  def after_resending_confirmation_instructions_path_for(resource_name)
    verify_email_path
  end
end
