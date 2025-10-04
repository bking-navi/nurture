# Thread-safe storage for the current request context
# This allows us to store the current advertiser for the duration of a request
# without passing it around as a parameter everywhere
#
# Usage:
#   Current.advertiser = @advertiser
#   Current.advertiser.campaigns.all  # automatically scoped
#
class Current < ActiveSupport::CurrentAttributes
  attribute :advertiser
  attribute :user
end

