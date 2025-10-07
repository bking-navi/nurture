module Agencies
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :set_agency
    before_action :require_agency_access
    layout 'sidebar'
    
    private
    
    def set_agency
      @agency = current_user.agencies.find_by(slug: params[:slug])
      
      unless @agency
        flash[:error] = "Agency not found or you don't have access"
        redirect_to advertisers_path
        return
      end
      
      Current.user = current_user
      Current.agency = @agency
      Current.context_type = :agency
      Current.membership = current_user.agency_memberships.find_by(agency: @agency)
      Current.advertiser = nil
    end
    
    def require_agency_access
      unless Current.membership&.accepted?
        flash[:error] = "You don't have access to this agency"
        redirect_to advertisers_path
      end
    end
    
    def require_admin_access
      unless Current.membership&.role&.in?(['owner', 'admin'])
        flash[:error] = "You don't have permission to perform this action"
        redirect_to agency_dashboard_path(@agency.slug)
      end
    end
  end
end

