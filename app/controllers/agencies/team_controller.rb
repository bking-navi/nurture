module Agencies
  class TeamController < BaseController
    def index
      @members = @agency.agency_memberships.includes(:user, :agency_client_assignments).order(created_at: :asc)
      @pending_invitations = @agency.agency_invitations.pending.order(created_at: :desc)
    end
  end
end

