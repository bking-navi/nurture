class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :verify_campaign_access!
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :send_now, :calculate_cost, :preview, :preview_live]
  before_action :verify_editable!, only: [:edit, :update, :destroy, :send_now]
  
  layout "sidebar"
  
  def index
    @campaigns = @advertiser.campaigns
                            .includes(:created_by_user, :creative)
                            .recent
    
    # Filter by status if provided
    if params[:status].present?
      case params[:status]
      when 'completed'
        # Show both completed and completed_with_errors
        @campaigns = @campaigns.where(status: [:completed, :completed_with_errors])
      when 'sent'
        # Legacy support - redirect to completed filter
        @campaigns = @campaigns.where(status: [:completed, :completed_with_errors])
      else
        # Exact status match
        @campaigns = @campaigns.where(status: params[:status]) if Campaign.statuses.key?(params[:status])
      end
    end
    
    @campaigns = @campaigns.page(params[:page]).per(20)
  end
  
  def show
    @campaign_contacts = @campaign.campaign_contacts
                                  .order(created_at: :desc)
                                  .page(params[:page])
                                  .per(50)
  end
  
  def new
    @campaign = @advertiser.campaigns.build
  end
  
  def create
    @campaign = @advertiser.campaigns.build(campaign_params)
    @campaign.created_by_user = current_user
    @campaign.status = :draft
    
    if @campaign.save
      redirect_to edit_campaign_path(@advertiser.slug, @campaign), 
                  notice: 'Campaign created. Add recipients to continue.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    # Get current tab or default to recipients
    @current_tab = params[:tab] || 'recipients'
    
    # Load templates and palettes for design tab
    if @current_tab == 'design'
      @templates = PostcardTemplate.active.by_sort_order
      @color_palettes = ColorPalette.available_for(@advertiser)
      
      # Preselect first template and default palette if none selected
      if @campaign.postcard_template_id.blank? && @templates.any?
        @campaign.postcard_template_id = @templates.first.id
      end
      
      if @campaign.color_palette_id.blank? && @color_palettes.any?
        # Try to find default palette, or use first one
        default_palette = @color_palettes.find_by(is_default: true) || @color_palettes.first
        @campaign.color_palette_id = default_palette.id
      end
    end
  end
  
  def update
    if @campaign.update(campaign_params)
      # If saving from design tab with save & continue, go to review
      if params[:tab] == 'design' && params[:commit] == 'Save & Continue'
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'review'), 
                    notice: 'Design saved!'
      else
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: params[:tab]), 
                    notice: 'Campaign updated.'
      end
    else
      @current_tab = params[:tab] || 'recipients'
      
      # Reload templates and palettes if on design tab
      if @current_tab == 'design'
        @templates = PostcardTemplate.active.by_sort_order
        @color_palettes = ColorPalette.available_for(@advertiser)
      end
      
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    unless @campaign.deletable?
      redirect_to campaigns_path(@advertiser.slug), 
                  alert: 'Cannot delete campaign that has been sent.'
      return
    end
    
    @campaign.destroy
    redirect_to campaigns_path(@advertiser.slug), 
                notice: 'Campaign deleted.'
  end
  
  def calculate_cost
    @campaign.calculate_estimated_cost!
    
    respond_to do |format|
      format.html do
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'review'),
                    notice: "Estimated cost: #{helpers.number_to_currency(@campaign.estimated_cost_dollars)}"
      end
      format.json do
        render json: { 
          estimated_cost_cents: @campaign.estimated_cost_cents,
          estimated_cost_dollars: @campaign.estimated_cost_dollars,
          recipient_count: @campaign.recipient_count
        }
      end
    end
  end
  
  def send_now
    unless @campaign.sendable?
      redirect_to edit_campaign_path(@advertiser.slug, @campaign),
                  alert: 'Campaign not ready to send. Add recipients and select a template.'
      return
    end
    
    # Calculate final cost
    @campaign.calculate_estimated_cost!
    
    @campaign.send_now!
    redirect_to campaign_path(@advertiser.slug, @campaign),
                notice: 'Campaign is being sent. You will receive an email when complete.'
  end
  
  def preview
    # Render HTML preview for the campaign (static, for initial load)
    side = params[:side] || 'front'
    
    # Sample contact data for preview
    sample_contact_data = {
      first_name: "John",
      last_name: "Doe",
      full_name: "John Doe",
      company: "Acme Corp",
      email: "john@acmecorp.com",
      phone: "(555) 123-4567"
    }
    
    html = if side == 'front'
      @campaign.render_front_html(sample_contact_data)
    else
      @campaign.render_back_html(sample_contact_data)
    end
    
    render html: html.html_safe, layout: false
  end
  
  def preview_live
    # Render live preview with current form data
    side = params[:side] || 'front'
    
    # Get template and palette from params (may be different from saved campaign)
    template_id = params[:postcard_template_id] || @campaign.postcard_template_id
    palette_id = params[:color_palette_id] || @campaign.color_palette_id
    template_data = params[:template_data]&.permit! || @campaign.template_data || {}
    
    # Load template and palette
    template = PostcardTemplate.find_by(id: template_id)
    palette = ColorPalette.find_by(id: palette_id)
    
    unless template
      render html: "<div style='padding: 40px; text-align: center; color: #999;'>Select a template to see preview</div>".html_safe, layout: false
      return
    end
    
    # Build complete data for rendering
    data = template_data.to_h.symbolize_keys
    
    # Add advertiser defaults
    data[:logo_url] ||= @advertiser.logo_url if @advertiser.respond_to?(:logo_url)
    data[:company_name] ||= @advertiser.name
    data[:website] ||= @advertiser.website_url
    data[:phone] ||= @advertiser.phone if @advertiser.respond_to?(:phone)
    
    # Add color palette colors
    if palette
      palette.colors.each do |key, value|
        data["color_#{key}".to_sym] ||= value
      end
    end
    
    # Add sample contact data for personalization
    data.merge!(
      first_name: "John",
      last_name: "Doe",
      full_name: "John Doe",
      company: "Acme Corp",
      email: "john@acmecorp.com",
      phone: "(555) 123-4567"
    )
    
    # Render the appropriate side
    html = if side == 'front'
      template.render_front(data)
    else
      template.render_back(data)
    end
    
    render html: html.html_safe, layout: false
  end
  
  private
  
  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end
  
  def verify_campaign_access!
    unless current_user.can_manage_campaigns?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), 
                  alert: 'You do not have permission to manage campaigns.'
    end
  end
  
  def set_campaign
    @campaign = @advertiser.campaigns.find(params[:id])
  end
  
  def verify_editable!
    return if @campaign.editable?
    
    redirect_to campaign_path(@advertiser.slug, @campaign),
                alert: 'Campaign cannot be edited after sending.'
  end
  
  def campaign_params
    params.require(:campaign).permit(
      :name, :description, :template_id, :template_name, 
      :template_thumbnail_url, :front_message, :back_message,
      :postcard_template_id, :color_palette_id,
      :creative_id,
      :front_pdf, :back_pdf,
      template_data: {}
    )
  end
end

