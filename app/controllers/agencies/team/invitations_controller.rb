module Agencies
  module Team
    class InvitationsController < BaseController
      before_action :require_admin_access
      
      def new
        @invitation = @agency.agency_invitations.new
      end
      
      def create
        @invitation = @agency.agency_invitations.new(invitation_params)
        @invitation.invited_by = current_user
        
        if @invitation.save
          # Send invitation email
          begin
            @invitation.send_invitation_email
            flash[:notice] = "Invitation sent to #{@invitation.email}"
          rescue => e
            Rails.logger.error "Failed to send invitation email: #{e.message}"
            flash[:notice] = "Invitation created for #{@invitation.email}, but email failed to send"
          end
          
          redirect_to agency_team_path(@agency.slug)
        else
          render :new, status: :unprocessable_entity
        end
      end
      
      def destroy
        @invitation = @agency.agency_invitations.find(params[:id])
        @invitation.decline!
        
        flash[:notice] = "Invitation cancelled"
        redirect_to agency_team_path(@agency.slug)
      end
      
      private
      
      def invitation_params
        params.require(:agency_invitation).permit(:email, :role)
      end
    end
  end
end

