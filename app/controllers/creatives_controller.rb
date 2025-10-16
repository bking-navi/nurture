class CreativesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :verify_access!
  before_action :set_creative, only: [:show, :edit, :update, :destroy, :approve, :reject, :regenerate_proof]
  
  layout "sidebar"

  def index
    @creatives = @advertiser.creatives.active
    
    # Apply filters
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @creatives = @creatives.where("name ILIKE ? OR description ILIKE ?", search_term, search_term)
    end
    
    if params[:size].present?
      @creatives = @creatives.where(postcard_template_id: params[:size])
    end
    
    if params[:tag].present?
      @creatives = @creatives.with_tag(params[:tag])
    end
    
    # Apply sorting
    @creatives = case params[:sort]
    when 'popular'
      @creatives.popular
    when 'name'
      @creatives.by_name
    else
      @creatives.recent
    end
    
    @creatives = @creatives.includes(:postcard_template, :created_by_user)
    
    set_current_advertiser(@advertiser)
  end

  def show
    @campaigns = @creative.campaigns.recent.limit(10)
    set_current_advertiser(@advertiser)
  end

  def new
    @creative = @advertiser.creatives.build
    @postcard_templates = PostcardTemplate.all
    set_current_advertiser(@advertiser)
  end

  def create
    @creative = @advertiser.creatives.build(creative_params)
    @creative.created_by_user = current_user
    
    if @creative.save
      redirect_to creative_path(@advertiser.slug, @creative), 
                  notice: 'Creative saved! Generating proof for approval...'
    else
      @postcard_templates = PostcardTemplate.all
      set_current_advertiser(@advertiser)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @postcard_templates = PostcardTemplate.all
    set_current_advertiser(@advertiser)
  end

  def update
    if @creative.update(creative_params)
      redirect_to creative_path(@advertiser.slug, @creative), 
                  notice: 'Creative updated successfully!'
    else
      @postcard_templates = PostcardTemplate.all
      set_current_advertiser(@advertiser)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @creative.used? && !params[:confirm]
      redirect_to creative_path(@advertiser.slug, @creative),
                  alert: "This creative has been used in #{@creative.usage_count} campaigns. Are you sure you want to delete it?"
      return
    end
    
    @creative.destroy
    redirect_to creatives_path(@advertiser.slug), 
                notice: 'Creative deleted successfully.'
  end
  
  def approve
    @creative.approve!(current_user)
    redirect_to creative_path(@advertiser.slug, @creative),
                notice: 'Creative approved! It can now be used in campaigns.'
  end
  
  def reject
    reason = params[:reason].presence || 'No reason provided'
    @creative.reject!(current_user, reason)
    redirect_to creative_path(@advertiser.slug, @creative),
                notice: 'Creative rejected.'
  end
  
  def regenerate_proof
    @creative.regenerate_proof!
    redirect_to creative_path(@advertiser.slug, @creative),
                notice: 'Regenerating proof...'
  end

  private

  def set_advertiser
    @advertiser = find_advertiser_by_slug(params[:advertiser_slug])
    
    unless @advertiser
      redirect_to advertisers_path, alert: 'Advertiser not found or you do not have access'
      return
    end
    
    set_current_advertiser(@advertiser)
  end

  def verify_access!
    unless current_user.has_access_to?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug), 
                  alert: 'You do not have permission to manage creatives.'
    end
  end

  def set_creative
    @creative = @advertiser.creatives.find(params[:id])
  end

  def creative_params
    params.require(:creative).permit(
      :name,
      :description,
      :postcard_template_id,
      :status,
      :front_pdf,
      :back_pdf,
      tags: []
    )
  end
end
