require 'csv'

class SuppressionListCsvImporter
  attr_reader :advertiser, :file, :imported, :skipped, :errors

  def initialize(advertiser:, file:)
    @advertiser = advertiser
    @file = file
    @imported = 0
    @skipped = 0
    @errors = []
  end

  def import
    return { success: false, errors: ['No file provided'] } unless file.present?

    begin
      csv_content = File.read(file.path)
      csv = CSV.parse(csv_content, headers: true, header_converters: :symbol)

      csv.each_with_index do |row, index|
        process_row(row, index + 2) # +2 because CSV is 1-indexed and has header
      end

      {
        success: true,
        imported: @imported,
        skipped: @skipped,
        errors: @errors
      }
    rescue CSV::MalformedCSVError => e
      { success: false, errors: ["Invalid CSV format: #{e.message}"] }
    rescue => e
      { success: false, errors: ["Error processing file: #{e.message}"] }
    end
  end

  def self.sample_csv
    CSV.generate do |csv|
      csv << ['email', 'first_name', 'last_name', 'address_line1', 'address_line2', 'address_city', 'address_state', 'address_zip', 'reason']
      csv << ['john@example.com', 'John', 'Doe', '123 Main St', 'Apt 4', 'San Francisco', 'CA', '94102', 'Customer request']
      csv << ['', 'Jane', 'Smith', '456 Oak Ave', '', 'Oakland', 'CA', '94601', 'Bad address']
      csv << ['bob@example.com', 'Bob', 'Johnson', '', '', '', '', '', 'Unsubscribed via email']
    end
  end

  private

  def process_row(row, line_number)
    entry = advertiser.suppression_list_entries.build(
      email: row[:email].presence,
      first_name: row[:first_name].presence,
      last_name: row[:last_name].presence,
      address_line1: row[:address_line1].presence,
      address_line2: row[:address_line2].presence,
      address_city: row[:address_city].presence,
      address_state: row[:address_state].presence,
      address_zip: row[:address_zip].presence,
      reason: row[:reason].presence
    )

    if entry.save
      @imported += 1
    else
      @skipped += 1
      @errors << "Line #{line_number}: #{entry.errors.full_messages.join(', ')}"
    end
  rescue => e
    @skipped += 1
    @errors << "Line #{line_number}: #{e.message}"
  end
end

