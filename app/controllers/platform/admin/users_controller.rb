module Platform
  module Admin
    class UsersController < BaseController
      def index
        @users = User.includes(:advertiser_memberships, :agency_memberships)
                     .order(created_at: :desc)
                     .page(params[:page]).per(50)
      end
      
      def show
        @user = User.find(params[:id])
        @advertiser_memberships = @user.advertiser_memberships.includes(:advertiser).order(created_at: :desc)
        @agency_memberships = @user.agency_memberships.includes(:agency).order(created_at: :desc)
      end
      
      def toggle_platform_admin
        @user = User.find(params[:id])
        
        # Prevent removing your own platform admin access
        if @user.id == current_user.id
          flash[:error] = "You cannot remove your own platform admin access"
          redirect_to platform_admin_user_path(@user) and return
        end
        
        if @user.platform_admin?
          @user.update!(platform_role: nil)
          flash[:notice] = "#{@user.display_name} is no longer a platform admin"
        else
          @user.update!(platform_role: 'admin')
          flash[:notice] = "#{@user.display_name} is now a platform admin"
        end
        
        redirect_to platform_admin_user_path(@user)
      end
    end
  end
end

