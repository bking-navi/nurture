module Agencies
  class ClientsController < BaseController
    def index
      # Same as dashboard but different view
      @client_accesses = @agency.advertiser_agency_accesses.active.includes(:advertiser)
      
      # If user is not owner/admin, filter to only assigned clients
      unless Current.membership.role.in?(['owner', 'admin'])
        assigned_access_ids = Current.membership.agency_client_assignments
                                      .pluck(:advertiser_agency_access_id)
        @client_accesses = @client_accesses.where(id: assigned_access_ids)
      end
    end
  end
end

