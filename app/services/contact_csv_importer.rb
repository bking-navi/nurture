require 'csv'

class ContactCsvImporter
  attr_reader :advertiser, :file, :errors
  
  def initialize(advertiser:, file:)
    @advertiser = advertiser
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
    duplicate_count = 0
    
    rows.each_with_index do |row, index|
      contact = build_contact_from_row(row)
      
      # Check for duplicate email
      if contact.email.present? && advertiser.contacts.exists?(email: contact.email)
        duplicate_count += 1
        @errors << "Row #{index + 2}: Email #{contact.email} already exists"
        next
      end
      
      if contact.valid?
        contact.save!
        imported_count += 1
      else
        invalid_count += 1
        @errors << "Row #{index + 2}: #{contact.errors.full_messages.join(', ')}"
      end
    end
    
    build_result(imported_count, invalid_count, duplicate_count)
  rescue => e
    Rails.logger.error "Contact CSV import error: #{e.message}\n#{e.backtrace.join("\n")}"
    @errors << "Import failed: #{e.message}"
    build_result(0, 0, 0)
  end
  
  # Generate sample CSV for download
  def self.sample_csv
    CSV.generate(headers: true) do |csv|
      csv << [
        'first_name', 'last_name', 'email', 'phone',
        'address_line1', 'address_line2', 'city', 'state', 'zip'
      ]
      
      # Add example rows
      csv << [
        'John', 'Doe', 'john@example.com', '555-1234',
        '1234 Main St', '', 'San Francisco', 'CA', '94111'
      ]
      csv << [
        'Jane', 'Smith', 'jane@example.com', '555-5678',
        '5678 Oak Ave', 'Apt 2', 'Los Angeles', 'CA', '90001'
      ]
    end
  end
  
  private
  
  def validate_headers(headers)
    required = %w[first_name last_name]
    optional = %w[email phone address_line1 address_line2 city state zip]
    
    missing = required - headers.map(&:downcase)
    
    if missing.any?
      @errors << "Missing required columns: #{missing.join(', ')}"
      return false
    end
    
    true
  end
  
  def build_contact_from_row(row)
    # Create contact with Advertiser as source (manually entered)
    advertiser.contacts.build(
      first_name: row['first_name']&.strip,
      last_name: row['last_name']&.strip,
      email: row['email']&.strip,
      phone: row['phone']&.strip,
      default_address: build_address_from_row(row),
      source_type: 'Advertiser',
      source_id: advertiser.id,
      external_id: SecureRandom.uuid,
      accepts_marketing: true
    )
  end
  
  def build_address_from_row(row)
    # Only build address if at least address_line1 is present
    return nil unless row['address_line1'].present?
    
    {
      'address1' => row['address_line1']&.strip,
      'address2' => row['address_line2']&.strip,
      'city' => row['city']&.strip,
      'state' => row['state']&.strip&.upcase,
      'zip' => row['zip']&.strip,
      'country_code' => 'US'
    }
  end
  
  def build_result(imported, invalid, duplicate = 0)
    {
      success: @errors.empty? || imported > 0,
      imported: imported,
      invalid: invalid,
      duplicate: duplicate,
      errors: @errors
    }
  end
end

