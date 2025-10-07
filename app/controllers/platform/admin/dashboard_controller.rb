module Platform
  module Admin
    class DashboardController < BaseController
      def index
        @advertisers_count = Advertiser.count
        @agencies_count = 0 # Will update when agencies are created
        @users_count = User.count
        @recent_advertisers = Advertiser.includes(:users, :advertiser_memberships)
                                       .order(created_at: :desc)
                                       .limit(10)
      end
    end
  end
end

