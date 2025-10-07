# Thread-safe storage for the current request context
# This allows us to store the current advertiser/agency/platform context for the duration of a request
# without passing it around as a parameter everywhere
#
# Usage:
#   Current.advertiser = @advertiser
#   Current.advertiser.campaigns.all  # automatically scoped
#   Current.context_type = :platform
#
class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :advertiser
  attribute :agency
  attribute :membership  # AdvertiserMembership or AgencyMembership
  attribute :context_type  # :platform, :advertiser, :agency
  
  def platform_mode?
    context_type == :platform
  end
  
  def advertiser_mode?
    context_type == :advertiser
  end
  
  def agency_mode?
    context_type == :agency
  end
  
  def current_context
    case context_type
    when :platform then 'Platform Admin'
    when :advertiser then advertiser
    when :agency then agency
    else nil
    end
  end
  
  def current_context_name
    case context_type
    when :platform then 'Platform Admin'
    when :advertiser then advertiser&.name
    when :agency then agency&.name
    else 'Unknown'
    end
  end
end

