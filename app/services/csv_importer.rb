require 'csv'

class CsvImporter
  attr_reader :campaign, :file, :errors
  
  def initialize(campaign:, file:)
    @campaign = campaign
    @file = file
    @errors = []
  end
  
  def import
    begin
      rows = CSV.parse(file.read, headers: true)
    rescue CSV::MalformedCSVError => e
      @errors << "Invalid CSV format: #{e.message}"
      return build_result(0, 0)
    end
    
    # Validate headers
    return build_result(0, 0) unless validate_headers(rows.headers)
    
    imported_count = 0
    invalid_count = 0
    
    rows.each_with_index do |row, index|
      contact = build_contact_from_row(row)
      
      if contact.valid?
        contact.save!
        imported_count += 1
      else
        invalid_count += 1
        @errors << "Row #{index + 2}: #{contact.errors.full_messages.join(', ')}"
      end
    end
    
    # Update campaign counts
    campaign.update_counts!
    
    build_result(imported_count, invalid_count)
  rescue => e
    Rails.logger.error "CSV import error: #{e.message}\n#{e.backtrace.join("\n")}"
    @errors << "Import failed: #{e.message}"
    build_result(0, 0)
  end
  
  # Generate sample CSV for download
  def self.sample_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'first_name', 'last_name', 'company', 
        'address_line1', 'address_line2', 'city', 'state', 'zip',
        'email', 'phone'
      ]
      
      # Add example rows
      csv << [
        'John', 'Doe', 'Acme Corp',
        '1234 Main St', '', 'San Francisco', 'CA', '94111',
        'john@example.com', '555-1234'
      ]
      csv << [
        'Jane', 'Smith', '',
        '5678 Oak Ave', 'Apt 2', 'Los Angeles', 'CA', '90001',
        'jane@example.com', ''
      ]
    end
  end
  
  private
  
  def validate_headers(headers)
    required = %w[first_name last_name address_line1 city state zip]
    missing = required - headers.map(&:downcase)
    
    if missing.any?
      @errors << "Missing required columns: #{missing.join(', ')}"
      return false
    end
    
    true
  end
  
  def build_contact_from_row(row)
    campaign.campaign_contacts.build(
      first_name: row['first_name']&.strip,
      last_name: row['last_name']&.strip,
      company: row['company']&.strip,
      address_line1: row['address_line1']&.strip,
      address_line2: row['address_line2']&.strip,
      address_city: row['city']&.strip,
      address_state: row['state']&.strip&.upcase,
      address_zip: row['zip']&.strip,
      email: row['email']&.strip,
      phone: row['phone']&.strip,
      address_country: 'US'
    )
  end
  
  def build_result(imported, invalid)
    {
      success: @errors.empty? || imported > 0,
      imported: imported,
      invalid: invalid,
      errors: @errors
    }
  end
end

