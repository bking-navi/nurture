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
        @agencies = @advertiser.advertiser_agency_accesses.includes(:agency)
        
        # Stats
        @campaigns_count = @advertiser.campaigns.count
        @contacts_count = @advertiser.contacts.count
        
        # Billing info
        @balance = @advertiser.balance_dollars
        @payment_method = @advertiser.payment_method_summary
        @recent_transactions = @advertiser.balance_transactions.recent.limit(10)
        @total_spent = @advertiser.balance_transactions.charges.sum(:amount_cents).abs / 100.0
        @total_deposited = @advertiser.balance_transactions.deposits.sum(:amount_cents) / 100.0
        @total_fees_absorbed = @advertiser.balance_transactions.sum(:stripe_fee_cents) / 100.0
      end
    end
  end
end

