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
    end
  end
end

