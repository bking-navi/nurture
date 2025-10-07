module Platform
  module Admin
    class CampaignsController < BaseController
      def index
        @campaigns = Campaign.includes(:advertiser, :created_by_user)
                             .order(created_at: :desc)
                             .page(params[:page]).per(50)
        
        # Apply filters
        if params[:status].present?
          @campaigns = @campaigns.where(status: params[:status])
        end
        
        if params[:advertiser_id].present?
          @campaigns = @campaigns.where(advertiser_id: params[:advertiser_id])
        end
        
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          @campaigns = @campaigns.where('name ILIKE ?', search_term)
        end
        
        # Calculate stats
        @total_campaigns = Campaign.count
        @draft_count = Campaign.where(status: 'draft').count
        @sending_count = Campaign.where(status: 'sending').count
        @sent_count = Campaign.where(status: 'sent').count
        @failed_count = Campaign.where(status: 'failed').count
        
        # Cost stats
        @total_cost_estimate = Campaign.where(status: 'sent').sum(:actual_cost_cents)
        @campaigns_today = Campaign.where('created_at >= ?', Time.current.beginning_of_day).count
        @campaigns_this_week = Campaign.where('created_at >= ?', Time.current.beginning_of_week).count
        
        # Postcard stats
        @total_postcards_sent = CampaignContact.where.not(lob_postcard_id: nil).count
        @total_postcards_failed = CampaignContact.where(status: 'failed').count
        
        @advertisers = Advertiser.order(:name)
      end
      
      def show
        @campaign = Campaign.includes(:advertiser, :created_by_user, :campaign_contacts).find(params[:id])
        @api_logs = LobApiLog.where(campaign: @campaign).recent.limit(20)
        @recent_contacts = @campaign.campaign_contacts.includes(:contact).order(created_at: :desc).limit(10)
      end
    end
  end
end

