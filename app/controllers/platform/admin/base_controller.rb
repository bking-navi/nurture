module Platform
  module Admin
    class BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :require_platform_admin
      before_action :set_platform_context
      layout 'sidebar'
      
      private
      
      def require_platform_admin
        unless current_user&.platform_admin?
          flash[:error] = "You don't have permission to access the platform admin."
          redirect_to root_path
        end
      end
      
      def set_platform_context
        Current.user = current_user
        Current.context_type = :platform
        Current.advertiser = nil
        Current.agency = nil
        Current.membership = nil
      end
    end
  end
end

