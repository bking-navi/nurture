module Platform
  module Admin
    class LobApiLogsController < BaseController
      def index
        @logs = LobApiLog.includes(:advertiser, :campaign)
                         .recent
                         .page(params[:page]).per(50)
        
        # Apply filters
        if params[:advertiser_id].present?
          @logs = @logs.where(advertiser_id: params[:advertiser_id])
        end
        
        if params[:campaign_id].present?
          @logs = @logs.where(campaign_id: params[:campaign_id])
        end
        
        if params[:success].present?
          @logs = params[:success] == 'true' ? @logs.successful : @logs.failed
        end
        
        if params[:endpoint].present?
          @logs = @logs.where('endpoint LIKE ?', "%#{params[:endpoint]}%")
        end
        
        if params[:date_from].present?
          @logs = @logs.where('created_at >= ?', Date.parse(params[:date_from]))
        end
        
        if params[:date_to].present?
          @logs = @logs.where('created_at <= ?', Date.parse(params[:date_to]).end_of_day)
        end
        
        # Calculate stats
        @total_logs = @logs.count
        @total_cost = @logs.sum(:cost_cents)
        @success_count = @logs.successful.count
        @failed_count = @logs.failed.count
        @avg_duration = @logs.average(:duration_ms)&.to_i || 0
        
        # Get stats for all time
        @all_time_stats = {
          total_logs: LobApiLog.count,
          total_cost: LobApiLog.sum(:cost_cents),
          success_rate: LobApiLog.success_rate,
          total_postcards: LobApiLog.postcards.count
        }
        
        @advertisers = Advertiser.order(:name)
      end
      
      def show
        @log = LobApiLog.includes(:advertiser, :campaign).find(params[:id])
      end
    end
  end
end

