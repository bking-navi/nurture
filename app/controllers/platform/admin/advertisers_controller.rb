module Platform
  module Admin
    class AdvertisersController < BaseController
      def index
        @advertisers = Advertiser.includes(:users, :advertiser_memberships)
                                 .order(created_at: :desc)
                                 .page(params[:page]).per(25)
      end
      
      def show
        @advertiser = Advertiser.find(params[:id])
        @members = @advertiser.advertiser_memberships.includes(:user).order(created_at: :asc)
        @campaigns_count = @advertiser.campaigns.count
        @contacts_count = @advertiser.contacts.count
        # @agencies = @advertiser.advertiser_agency_accesses.includes(:agency) # Will add when agencies exist
      end
    end
  end
end

