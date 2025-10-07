module Agencies
  class DashboardController < BaseController
    def index
      # Get all active client relationships
      @client_accesses = @agency.advertiser_agency_accesses.active.includes(:advertiser)
      
      # If user is not owner/admin, filter to only assigned clients
      unless Current.membership&.role&.in?(['owner', 'admin'])
        assigned_access_ids = Current.membership.agency_client_assignments
                                      .pluck(:advertiser_agency_access_id)
        @client_accesses = @client_accesses.where(id: assigned_access_ids)
      end
      
      @pending_invitations = @agency.advertiser_agency_accesses.pending.includes(:advertiser)
    end
  end
end

