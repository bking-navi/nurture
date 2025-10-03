class UserMailer < ApplicationMailer
  def confirmation_instructions(record, token, opts = {})
    verification_url = user_confirmation_url(confirmation_token: token)
    
    # In development, log the verification URL
    if Rails.env.development?
      Rails.logger.info "=== EMAIL VERIFICATION ==="
      Rails.logger.info "To: #{record.email}"
      Rails.logger.info "Verification URL: #{verification_url}"
      Rails.logger.info "Sending via Loops..."
      Rails.logger.info "========================"
    end

    # Use Loops.so to send email verification in production
    client = LoopsClient.new
    
    template_id = Rails.application.credentials.dig(:loops, :templates, :email_verification) || 'email_verification'
    
    client.send_transactional_email(
      email: record.email,
      template_id: template_id,
      variables: {
        first_name: record.first_name,
        verification_url: verification_url
      }
    )
  end

  def reset_password_instructions(record, token, opts = {})
    # In development, just log the reset URL instead of sending email
    if Rails.env.development?
      reset_url = edit_user_password_url(reset_password_token: token)
      Rails.logger.info "=== PASSWORD RESET ==="
      Rails.logger.info "To: #{record.email}"
      Rails.logger.info "Reset URL: #{reset_url}"
      Rails.logger.info "===================="
      return
    end

    # Use Loops.so for password reset emails in production
    client = LoopsClient.new
    
    reset_url = edit_user_password_url(reset_password_token: token)
    template_id = Rails.application.credentials.dig(:loops, :templates, :password_reset) || 'password_reset'
    
    client.send_transactional_email(
      email: record.email,
      template_id: template_id,
      variables: {
        first_name: record.first_name,
        reset_url: reset_url
      }
    )
  end
end
