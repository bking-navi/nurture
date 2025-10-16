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
      @suppression_stats = @advertiser.suppression_impact_stats
    end
    
    def preview_impact
      # Calculate stats with provided values (without saving)
      recent_order_days = params[:recent_order_days].to_i
      recent_mail_days = params[:recent_mail_days].to_i
      
      stats = calculate_suppression_stats(
        recent_order_days: recent_order_days,
        recent_mail_days: recent_mail_days
      )
      
      render json: stats
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
  
  def calculate_suppression_stats(recent_order_days:, recent_mail_days:)
    stats = {
      total_contacts: @advertiser.contacts.count,
      recent_orders_count: 0,
      recent_mail_count: 0,
      suppression_list_count: 0,
      total_suppressed: 0,
      percentage_suppressed: 0
    }
    
    return stats if stats[:total_contacts].zero?
    
    suppressed_contact_ids = Set.new
    
    # Count contacts who would be suppressed by recent orders rule
    if recent_order_days > 0
      order_suppressed = @advertiser.contacts
        .where("last_order_at >= ?", recent_order_days.days.ago)
        .pluck(:id)
      stats[:recent_orders_count] = order_suppressed.size
      suppressed_contact_ids.merge(order_suppressed)
    end
    
    # Count contacts who would be suppressed by recent mail rule
    if recent_mail_days > 0
      mail_suppressed = @advertiser.contacts
        .where("last_mailed_at >= ?", recent_mail_days.days.ago)
        .pluck(:id)
      stats[:recent_mail_count] = mail_suppressed.size
      suppressed_contact_ids.merge(mail_suppressed)
    end
    
    # Count contacts on suppression list
    if @advertiser.dnm_enabled
      stats[:suppression_list_count] = @advertiser.suppression_list_entries.count
      
      # Find contacts whose email matches suppression list
      suppressed_emails = @advertiser.suppression_list_entries.where.not(email: nil).pluck(:email)
      if suppressed_emails.any?
        suppressed_contact_ids.merge(
          @advertiser.contacts.where(email: suppressed_emails).pluck(:id)
        )
      end
    end
    
    stats[:total_suppressed] = suppressed_contact_ids.size
    stats[:percentage_suppressed] = stats[:total_contacts] > 0 ? 
      ((stats[:total_suppressed].to_f / stats[:total_contacts]) * 100).round : 0
    
    stats
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

