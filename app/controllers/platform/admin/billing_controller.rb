module Platform
  module Admin
    class BillingController < BaseController
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
    end
  end
end

