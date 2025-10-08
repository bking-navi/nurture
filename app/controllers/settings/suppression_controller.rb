module Settings
  class SuppressionController < ApplicationController
    before_action :authenticate_user!
    before_action :set_advertiser
    before_action :verify_settings_access!
    
    layout "sidebar"
    
    def show
      @dnm_entries = @advertiser.suppression_list_entries
                                .recent
                                .page(params[:page])
                                .per(50)
    end
    
    def update
      if @advertiser.update(suppression_params)
        redirect_to settings_suppression_path(@advertiser.slug),
                    notice: 'Suppression settings updated successfully.'
      else
        @dnm_entries = @advertiser.suppression_list_entries.recent.page(params[:page]).per(50)
        render :show, status: :unprocessable_entity
      end
    end
    
    def import_dnm
      file = params[:csv_file]
      
      unless file.present?
        redirect_to settings_suppression_path(@advertiser.slug),
                    alert: 'Please select a CSV file.'
        return
      end
      
      imported = 0
      skipped = 0
      errors_list = []
      
      begin
        CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
          next if row[:email].blank?
          
          entry = @advertiser.suppression_list_entries.build(
            email: row[:email],
            first_name: row[:first_name],
            last_name: row[:last_name],
            reason: row[:reason]
          )
          
          if entry.save
            imported += 1
          else
            if entry.errors[:email].any? { |e| e.include?("already") }
              skipped += 1
            else
              errors_list << "#{row[:email]}: #{entry.errors.full_messages.join(', ')}"
            end
          end
        end
        
        message = "Imported #{imported} entries"
        message += ", skipped #{skipped} duplicates" if skipped > 0
        
        if errors_list.any?
          redirect_to settings_suppression_path(@advertiser.slug),
                      notice: message,
                      alert: "#{errors_list.count} errors: #{errors_list.first(3).join('; ')}"
        else
          redirect_to settings_suppression_path(@advertiser.slug),
                      notice: message
        end
        
      rescue CSV::MalformedCSVError => e
        redirect_to settings_suppression_path(@advertiser.slug),
                    alert: "Invalid CSV file: #{e.message}"
      rescue => e
        redirect_to settings_suppression_path(@advertiser.slug),
                    alert: "Import failed: #{e.message}"
      end
    end
    
    def create_entry
      @entry = @advertiser.suppression_list_entries.build(entry_params)
      
      if @entry.save
        redirect_to settings_suppression_path(@advertiser.slug),
                    notice: 'Entry added to suppression list.'
      else
        @dnm_entries = @advertiser.suppression_list_entries.recent.page(params[:page]).per(50)
        flash.now[:alert] = @entry.errors.full_messages.join(', ')
        render :show, status: :unprocessable_entity
      end
    end
    
    def destroy_entry
      entry = @advertiser.suppression_list_entries.find(params[:id])
      entry.destroy
      
      redirect_to settings_suppression_path(@advertiser.slug),
                  notice: 'Entry removed from suppression list.'
    end
    
    def download_sample
      csv_data = [
        ['email', 'first_name', 'last_name', 'reason'],
        ['customer@example.com', 'John', 'Doe', 'Customer request'],
        ['optout@example.com', 'Jane', 'Smith', 'Unsubscribed']
      ].map(&:to_csv).join
      
      send_data csv_data,
                filename: "dnm_sample.csv",
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
    
  def verify_settings_access!
    unless current_user.can_manage_team?(@advertiser)
      redirect_to advertiser_dashboard_path(@advertiser.slug),
                  alert: 'You do not have permission to manage suppression settings.'
    end
  end
    
    def suppression_params
      params.require(:advertiser).permit(
        :recent_order_suppression_days,
        :recent_mail_suppression_days,
        :dnm_enabled
      )
    end
    
  def entry_params
    params.require(:suppression_list_entry).permit(
      :email,
      :first_name,
      :last_name,
      :reason,
      :address_line1,
      :address_line2,
      :address_city,
      :address_state,
      :address_zip
    )
  end
  end
end

