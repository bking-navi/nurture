module Agencies
  class ClientAssignmentsController < BaseController
    before_action :require_admin_access
    before_action :set_client_access
    
    def index
      @assignments = @client_access.agency_client_assignments.includes(agency_membership: :user)
      @available_members = @agency.agency_memberships.accepted.where.not(
        id: @assignments.pluck(:agency_membership_id)
      ).includes(:user)
    end
    
    def create
      membership = @agency.agency_memberships.find(params[:agency_membership_id])
      role = params[:role] || 'viewer'
      
      assignment = @client_access.agency_client_assignments.create!(
        agency_membership: membership,
        role: role
      )
      
      flash[:notice] = "#{membership.user.display_name} assigned to #{@client_access.advertiser.name}"
      redirect_to client_assignments_path(@agency.slug, @client_access.id)
    end
    
    def destroy
      assignment = @client_access.agency_client_assignments.find(params[:id])
      user_name = assignment.user.display_name
      assignment.destroy!
      
      flash[:notice] = "#{user_name} removed from this client"
      redirect_to client_assignments_path(@agency.slug, @client_access.id)
    end
    
    private
    
    def set_client_access
      @client_access = @agency.advertiser_agency_accesses.active.find(params[:client_id])
    end
  end
end

