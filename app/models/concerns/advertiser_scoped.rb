# AdvertiserScoped concern
#
# Automatically scopes all queries to the current advertiser context.
# This is the core of our multitenancy data isolation.
#
# Usage:
#   class Campaign < ApplicationRecord
#     include AdvertiserScoped
#   end
#
# Then all queries are automatically scoped:
#   Campaign.all           # => only current advertiser's campaigns
#   Campaign.find(id)      # => raises RecordNotFound if not current advertiser's
#   campaign.update(...)   # => only works if belongs to current advertiser
#
# Critical: This concern expects Current.advertiser to be set
#
module AdvertiserScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :advertiser

    # Validate that advertiser is always present
    validates :advertiser, presence: true

    # Default scope: only return records for current advertiser
    default_scope -> { 
      if Current.advertiser
        where(advertiser: Current.advertiser) 
      else
        # If no current advertiser is set, return none
        # This prevents accidentally leaking data
        none
      end
    }

    # Validation: Prevent changing advertiser after creation
    validate :advertiser_cannot_be_changed, on: :update

    private

    def advertiser_cannot_be_changed
      if advertiser_id_changed? && persisted?
        errors.add(:advertiser_id, "cannot be changed")
      end
    end
  end

  class_methods do
    # Escape hatch: unscoped access (use with extreme caution!)
    # Usage: Model.unscoped_to_advertiser { Model.where(...) }
    def unscoped_to_advertiser
      unscoped { yield }
    end
  end
end

