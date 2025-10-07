class ContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :verify_access!
  
  layout "sidebar"
  
  def index
    @contacts = @advertiser.contacts
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(50)
    
    # Set current advertiser context
    set_current_advertiser(@advertiser)
    
    # Filter by source type if provided
    if params[:source].present?
      case params[:source]
      when 'shopify'
        @contacts = @contacts.from_shopify
      when 'manual'
        @contacts = @contacts.where(source_type: 'Advertiser')
      end
    end
    
    # Search by name or email if provided
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @contacts = @contacts.where(
        "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
        search_term, search_term, search_term
      )
    end
  end
  
  def new
    @contact = @advertiser.contacts.build
    set_current_advertiser(@advertiser)
  end
  
  def create
    # Build contact with permitted attributes
    contact_attributes = contact_params.to_h.merge(
      source_type: 'Advertiser',
      source_id: @advertiser.id,
      external_id: SecureRandom.uuid,
      accepts_marketing: true
    )
    
    @contact = @advertiser.contacts.build(contact_attributes)
    
    # Build default_address from address params if present
    address_params = params[:contact].permit(:address_line1, :address_line2, :address_city, :address_state, :address_zip)
    if address_params[:address_line1].present?
      @contact.default_address = {
        'address1' => address_params[:address_line1],
        'address2' => address_params[:address_line2],
        'city' => address_params[:address_city],
        'state' => address_params[:address_state]&.upcase,
        'zip' => address_params[:address_zip],
        'country_code' => 'US'
      }
    end
    
    if @contact.save
      redirect_to audience_path(@advertiser.slug), 
                  notice: 'Contact added successfully.'
    else
      set_current_advertiser(@advertiser)
      render :new, status: :unprocessable_entity
    end
  end
  
  def import_csv
    file = params[:csv_file]
    
    unless file.present?
      redirect_to audience_path(@advertiser.slug),
                  alert: 'Please select a CSV file.'
      return
    end
    
    importer = ContactCsvImporter.new(advertiser: @advertiser, file: file)
    result = importer.import
    
    if result[:success]
      message = "Successfully imported #{result[:imported]} contact#{'s' unless result[:imported] == 1}."
      message += " #{result[:duplicate]} duplicate#{'s' unless result[:duplicate] == 1} skipped." if result[:duplicate] > 0
      message += " #{result[:invalid]} invalid." if result[:invalid] > 0
      
      if result[:invalid] > 0 || result[:duplicate] > 0
        redirect_to audience_path(@advertiser.slug),
                    notice: message,
                    alert: result[:errors].first(3).join('; ')
      else
        redirect_to audience_path(@advertiser.slug),
                    notice: message
      end
    else
      redirect_to audience_path(@advertiser.slug),
                  alert: "Import failed: #{result[:errors].join(', ')}"
    end
  end
  
  def download_sample
    send_data ContactCsvImporter.sample_csv,
              filename: "contacts_sample.csv",
              type: "text/csv"
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
                  alert: 'You do not have permission to view contacts.'
    end
  end
  
  def contact_params
    params.require(:contact).permit(
      :first_name, :last_name, :email, :phone
    )
  end
end

