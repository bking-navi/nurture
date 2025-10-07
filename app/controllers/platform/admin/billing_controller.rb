module Platform
  module Admin
    class BillingController < ApplicationController
      before_action :authenticate_user!
      before_action :require_platform_admin
      
      def index
        @advertisers = Advertiser.all.order(created_at: :desc)
        
        # Calculate aggregate statistics
        @total_balance = Advertiser.sum(:balance_cents)
        @total_pending_balance = Advertiser.sum(:pending_balance_cents)
        @advertisers_with_payment_methods = Advertiser.where.not(stripe_customer_id: nil).count
        @total_advertisers = @advertisers.count
        
        # Get recent transactions across all advertisers
        @recent_transactions = BalanceTransaction
          .includes(:advertiser, :processed_by)
          .order(created_at: :desc)
          .limit(50)
        
        # Calculate totals by transaction type
        @total_deposits = BalanceTransaction.deposits.sum(:amount_cents)
        @total_charges = BalanceTransaction.charges.sum(:amount_cents)
        @total_stripe_fees = BalanceTransaction.sum(:stripe_fee_cents)
        
        # Get advertisers with low balances
        @low_balance_advertisers = @advertisers.select { |a| a.below_low_balance_threshold? }
        
        # Get advertisers with pending ACH
        @pending_ach_advertisers = @advertisers.select { |a| a.has_pending_balance? }
      end
      
      private
      
      def require_platform_admin
        unless current_user.platform_admin?
          flash[:error] = "You don't have permission to access this area"
          redirect_to root_path
        end
      end
    end
  end
end

