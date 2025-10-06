class SegmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :verify_access!
  before_action :set_segment, only: [:show, :edit, :update, :destroy]
  
  layout "sidebar"
  
  def index
    @segments = @advertiser.segments.order(created_at: :desc)
    set_current_advertiser(@advertiser)
  end
  
  def show
    @contacts = @segment.contacts.page(params[:page]).per(50)
    set_current_advertiser(@advertiser)
  end
  
  def new
    @segment = @advertiser.segments.build
    set_current_advertiser(@advertiser)
  end
  
  def create
    @segment = @advertiser.segments.build(segment_params)
    
    if @segment.save
      redirect_to segment_path(@advertiser.slug, @segment), 
                  notice: 'Segment created successfully.'
    else
      set_current_advertiser(@advertiser)
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    set_current_advertiser(@advertiser)
  end
  
  def update
    if @segment.update(segment_params)
      redirect_to segment_path(@advertiser.slug, @segment), 
                  notice: 'Segment updated successfully.'
    else
      set_current_advertiser(@advertiser)
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @segment.destroy
    redirect_to segments_path(@advertiser.slug), 
                notice: 'Segment deleted successfully.'
  end
  
  def preview
    # Return count of contacts matching current filter params
    filters = params[:filters]&.permit(
      :source, :search, :city, :state, :zip,
      :rfm_segment, :min_orders, :max_orders,
      :min_spent, :max_spent, :min_avg_order,
      :days_since_last_order, :has_tag
    ).to_h || {}
    
    temp_segment = @advertiser.segments.build(filters: filters)
    count = temp_segment.contacts.count
    
    render json: { count: count }
  end
  
  private
  
  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end
  
  def set_segment
    @segment = @advertiser.segments.find(params[:id])
  end
  
  def verify_access!
    unless current_user.has_access_to?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), 
                  alert: 'You do not have permission to manage segments.'
    end
  end
  
  def segment_params
    params.require(:segment).permit(
      :name, :description,
      filters: [
        :source, :search, :city, :state, :zip,
        :rfm_segment, :min_orders, :max_orders,
        :min_spent, :max_spent, :min_avg_order,
        :days_since_last_order, :has_tag
      ]
    )
  end
end

