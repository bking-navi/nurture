class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Handle routing errors gracefully (security by obscurity)
  rescue_from ActionController::RoutingError, with: :handle_routing_error

  private

  # Find advertiser by slug, checking both direct membership and agency access
  def find_advertiser_by_slug(slug)
    return nil unless current_user
    
    # First, try direct membership
    advertiser = current_user.advertisers.find_by(slug: slug)
    return advertiser if advertiser
    
    # If not found, check agency access
    Advertiser.joins(advertiser_agency_accesses: { agency_client_assignments: :agency_membership })
              .where(advertisers: { slug: slug })
              .where(advertiser_agency_accesses: { status: 'accepted' })
              .where(agency_client_assignments: { agency_membership: current_user.agency_memberships.accepted })
              .first
  end

  # Set the current advertiser in thread-safe storage
  # This enables automatic scoping for all AdvertiserScoped models
  def set_current_advertiser(advertiser)
    Current.advertiser = advertiser
    Current.user = current_user if respond_to?(:current_user)
  end

  # Clear the current advertiser context
  def clear_current_advertiser
    Current.advertiser = nil
    Current.user = nil
  end

  # Silently redirect on routing errors (don't reveal system structure)
  def handle_routing_error
    if user_signed_in?
      redirect_to advertisers_path
    else
      redirect_to root_path
    end
  end
end
