class CampaignContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :set_campaign
  before_action :verify_campaign_editable!, except: [:retry]
  
  def new
    @contact = @campaign.campaign_contacts.build
  end
  
  def create
    @contact = @campaign.campaign_contacts.build(contact_params)
    
    if @contact.save
      # Optionally validate address with Lob
      if params[:validate_address] == '1'
        @contact.validate_address!
      end
      
      @campaign.update_counts!
      
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  notice: 'Recipient added.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    @contact = @campaign.campaign_contacts.find(params[:id])
    @contact.destroy
    
    @campaign.update_counts!
    
    redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                notice: 'Recipient removed.'
  end
  
  def retry
    @contact = @campaign.campaign_contacts.find(params[:id])
    
    unless @contact.failed?
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  alert: 'Only failed postcards can be retried.'
      return
    end
    
    # Reset the contact to pending status
    @contact.update!(
      status: :pending,
      send_error: nil,
      lob_postcard_id: nil,
      lob_response: nil
    )
    
    # Get advertiser's return address
    from_address = LobClient.format_address_editable(
      name: @advertiser.name,
      address_line1: @advertiser.street_address,
      address_city: @advertiser.city,
      address_state: @advertiser.state,
      address_zip: @advertiser.postal_code,
      address_country: @advertiser.country
    )
    
    # Retry sending immediately
    begin
      @contact.update!(status: :sending)
      
      postcard = LobClient.create_postcard(
        campaign_contact: @contact,
        campaign: @campaign,
        from_address: from_address
      )
      
      # Store only essential data from Lob response to avoid session overflow
      lob_data = {
        id: postcard.id,
        url: postcard.url,
        expected_delivery_date: postcard.expected_delivery_date,
        created_at: postcard.date_created
      }.to_json
      
      @contact.update!(
        lob_postcard_id: postcard.id,
        status: :sent,
        tracking_number: nil,
        tracking_url: postcard.url,
        expected_delivery_date: Date.parse(postcard.expected_delivery_date.to_s),
        actual_cost_cents: (postcard.try(:price).to_f * 100).to_i,
        lob_response: lob_data
      )
      
      # Update campaign counts and costs
      @campaign.update_counts!
      @campaign.update!(
        actual_cost_cents: @campaign.campaign_contacts.sum(:actual_cost_cents)
      )
      
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  notice: "Postcard retry successful!"
    rescue => e
      # Truncate error message if too long to avoid session overflow
      error_msg = e.message.truncate(200)
      
      @contact.update!(
        status: :failed,
        send_error: error_msg
      )
      
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  alert: "Retry failed: #{error_msg}"
    end
  end
  
  def import_csv
    file = params[:csv_file]
    
    unless file.present?
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: 'Please select a CSV file.'
      return
    end
    
    importer = CsvImporter.new(campaign: @campaign, file: file)
    result = importer.import
    
    if result[:success]
      if result[:invalid] > 0
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                    notice: "Imported #{result[:imported]} recipients. #{result[:invalid]} invalid (see below).",
                    alert: result[:errors].first(5).join('; ')
      else
        redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                    notice: "Successfully imported #{result[:imported]} recipients."
      end
    else
      redirect_to edit_campaign_path(@advertiser.slug, @campaign, tab: 'recipients'),
                  alert: "Import failed: #{result[:errors].join(', ')}"
    end
  end
  
  def download_sample
    send_data CsvImporter.sample_csv,
              filename: "campaign_recipients_sample.csv",
              type: "text/csv"
  end
  
  private
  
  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end
  
  def set_campaign
    @campaign = @advertiser.campaigns.find(params[:campaign_id])
  end
  
  def verify_campaign_editable!
    unless @campaign.editable?
      redirect_to campaign_path(@advertiser.slug, @campaign),
                  alert: 'Cannot modify recipients after campaign has been sent.'
    end
  end
  
  def contact_params
    params.require(:campaign_contact).permit(
      :first_name, :last_name, :company,
      :address_line1, :address_line2, :address_city, 
      :address_state, :address_zip, :email, :phone
    )
  end
end

