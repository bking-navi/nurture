class HomeController < ApplicationController
  def index
    # If user is signed in and has an advertiser, redirect to their dashboard
    if user_signed_in? && current_user.advertisers.any?
      redirect_to advertiser_dashboard_path(current_user.advertisers.first.slug)
    end
  end

  def verify_email
    # Show email verification instructions
  end

  def check_email
    # Show "check your email" confirmation page
  end
end
