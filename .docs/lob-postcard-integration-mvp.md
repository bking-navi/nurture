# Lob.com Postcard Integration - MVP Specification

## Overview

Building direct mail postcard campaign functionality using Lob.com API. Users can create campaigns, manually add/upload recipients, estimate costs, save drafts, and send postcards. Post-MVP will add scheduling, custom templates, and integration with Shopify contacts.

**Key principles:**
- Manual contact management for MVP (CSV upload + manual entry)
- Use Lob's pre-made templates (custom templates post-MVP)
- Support single and bulk sends
- Cost estimation before sending
- Draft management (save, edit, delete)
- Design for future scheduling (database ready, UI post-MVP)
- Track send status and delivery

---

## Tech Stack Additions

**New gems needed:**
- `lob` (official Lob Ruby gem) - for API integration
- `csv` (built-in) - for recipient uploads

**Existing stack:**
- Rails 8, SQLite (dev) / PostgreSQL (production)
- Sidekiq, Redis
- Loops.so for email notifications
- Existing Contact model (from Shopify spec, adapted for MVP)

---

## Core Entities

### Campaign

**Purpose:** Represents a postcard mailing campaign (single or bulk send).

**Attributes:**
- `advertiser_id` (foreign key, required)
- `name` (string, e.g., "Summer Sale 2024", required)
- `description` (text, optional campaign notes)
- `status` (enum: draft, scheduled, processing, sent, failed, cancelled)
- `template_id` (string, Lob template ID, e.g., "tmpl_abc123")
- `template_name` (string, cached template name for display)
- `template_thumbnail_url` (string, cached preview image)
- `front_message` (text, personalized message for front of postcard)
- `back_message` (text, personalized message for back of postcard)
- `merge_variables` (jsonb, template variables like {company_name, offer_code})
- `estimated_cost` (decimal, total estimated cost in cents)
- `actual_cost` (decimal, total actual cost in cents after sending)
- `recipient_count` (integer, cached count)
- `sent_count` (integer, successfully sent)
- `failed_count` (integer, failed to send)
- `delivered_count` (integer, delivered postcards)
- `scheduled_at` (timestamp, when to send - MVP: always nil, post-MVP: scheduling)
- `sent_at` (timestamp, when actually sent/processing started)
- `completed_at` (timestamp, when all postcards processed)
- `created_by_user_id` (foreign key to User)
- `created_at`, `updated_at`

**Relationships:**
- `belongs_to :advertiser`
- `belongs_to :created_by_user, class_name: 'User'`
- `has_many :postcards, dependent: :destroy`
- `has_many :campaign_contacts, dependent: :destroy`

**Methods:**
- `draft?` → status == 'draft'
- `sendable?` → draft? && recipient_count > 0 && template_id.present?
- `deletable?` → draft? (only drafts can be deleted)
- `total_cost_dollars` → actual_cost / 100.0 (convert cents to dollars)
- `estimated_cost_dollars` → estimated_cost / 100.0
- `calculate_estimated_cost!` → fetch Lob pricing and calculate total
- `send_now!` → validates and enqueues send job
- `cancel!` → cancels scheduled campaign (post-MVP)

**Validations:**
- `name`: required, length 1-100
- `advertiser_id`: required
- `template_id`: required to send (not for draft)
- `status`: valid enum value

**Scopes:**
- `draft` → where(status: 'draft')
- `scheduled` → where(status: 'scheduled')
- `sent` → where(status: 'sent')
- `recent` → order(created_at: :desc)

---

### CampaignContact

**Purpose:** Join table linking campaigns to recipients with individual send status.

**Attributes:**
- `campaign_id` (foreign key, required)
- `first_name` (string, required)
- `last_name` (string, required)
- `company` (string, optional)
- `address_line1` (string, required)
- `address_line2` (string, optional)
- `address_city` (string, required)
- `address_state` (string, required, 2-letter code)
- `address_zip` (string, required)
- `address_country` (string, default: 'US')
- `email` (string, optional, for notifications)
- `phone` (string, optional)
- `metadata` (jsonb, custom fields for merge variables)
- `lob_postcard_id` (string, Lob's postcard ID after creation)
- `status` (enum: pending, validating, sending, sent, in_transit, delivered, returned, failed)
- `estimated_cost_cents` (integer, cost in cents)
- `actual_cost_cents` (integer, actual billed amount)
- `tracking_number` (string, USPS tracking)
- `tracking_url` (string, Lob tracking URL)
- `expected_delivery_date` (date, estimated delivery)
- `delivered_at` (timestamp, actual delivery time)
- `send_error` (text, error message if failed)
- `lob_response` (jsonb, full Lob API response)
- `created_at`, `updated_at`

**Relationships:**
- `belongs_to :campaign`

**Methods:**
- `full_name` → "#{first_name} #{last_name}"
- `address_formatted` → multi-line formatted address
- `deliverable?` → status not in [failed, returned]
- `cost_dollars` → actual_cost_cents / 100.0

**Validations:**
- `campaign_id`: required
- `first_name`, `last_name`: required
- `address_line1`, `address_city`, `address_state`, `address_zip`: required
- `address_state`: 2 uppercase letters
- `address_zip`: valid format (5 digits or 5+4)
- `email`: valid format if present

**Indices:**
- `(campaign_id, status)` for filtering
- `(campaign_id, created_at)` for ordering
- `lob_postcard_id` unique for lookups

---

### Contact (Simplified MVP Version)

**Purpose:** Reusable contact list for future campaigns. Not required for MVP but sets foundation.

**Note:** For MVP, we'll store recipients directly in `CampaignContact`. Post-MVP, we can add a `contact_id` foreign key to link to reusable contacts from Shopify, uploads, etc.

**Future attributes** (post-Shopify integration):
- All fields from Shopify spec
- `source_type`, `source_id` (polymorphic)
- `external_id` (Shopify customer ID)

**MVP approach:**
- Each campaign has own recipients in `CampaignContact` table
- No contact reuse between campaigns
- When Shopify integration exists, add `contact_id` to `CampaignContact` (nullable)

---

## Lob.com API Integration

### API Setup

**Authentication:**
- Test API key: `test_*` (sandbox for development)
- Live API key: `live_*` (production)
- Store in Rails credentials: `Rails.application.credentials.dig(:lob, :api_key)`

**Gem installation:**
```ruby
# Gemfile
gem 'lob', '~> 6.0'
```

**Configuration:**
```ruby
# config/initializers/lob.rb
Lob.api_key = Rails.application.credentials.dig(:lob, :api_key) || ENV['LOB_API_KEY']
```

---

### Key Lob API Endpoints

**1. Address Verification**
```ruby
Lob::USVerification.verify(
  primary_line: "1234 Main St",
  city: "San Francisco",
  state: "CA",
  zip_code: "94111"
)
# Returns: validated address or error
```

**2. Create Postcard**
```ruby
Lob::Postcard.create(
  description: "Campaign: Summer Sale 2024",
  to: {
    name: "John Doe",
    address_line1: "1234 Main St",
    address_city: "San Francisco",
    address_state: "CA",
    address_zip: "94111"
  },
  from: {
    name: "Acme Corp",
    address_line1: "5678 Business Ave",
    address_city: "New York",
    address_state: "NY",
    address_zip: "10001"
  },
  front: "tmpl_abc123",  # Template ID
  back: "tmpl_xyz789",   # Or custom HTML
  merge_variables: {
    name: "John",
    offer_code: "SAVE20"
  },
  size: "6x9",  # or "4x6"
  mail_type: "usps_first_class"  # or "usps_standard"
)
# Returns: postcard object with id, tracking URL, expected delivery date
```

**3. Get Postcard Status**
```ruby
Lob::Postcard.retrieve("psc_abc123")
# Returns: postcard with updated status, tracking events
```

**4. List Templates**
```ruby
Lob::Template.list(limit: 50)
# Returns: available templates
```

**5. Cancel Postcard** (only before it's printed)
```ruby
Lob::Postcard.delete("psc_abc123")
# Returns: cancelled postcard (only works if not yet printed)
```

---

### Lob Pricing (as of 2024)

**Postcard pricing:**
- 4x6 postcards: $0.53 each (USPS First Class)
- 6x9 postcards: $1.05 each (USPS First Class)
- 6x11 postcards: $1.32 each (USPS First Class)

**Note:** Prices vary by mail type and volume discounts. MVP will:
1. Fetch real-time pricing from Lob API before sending
2. Cache pricing for 24 hours (unlikely to change)
3. Show users estimated cost before confirmation

---

### Lob Test Mode

**Development/Testing:**
- Use `test_*` API key
- Postcards not actually mailed
- Can verify integration without cost
- Returns realistic responses with tracking data

**Production:**
- Use `live_*` API key
- Real postcards printed and mailed
- Actual charges apply

---

## User Flows

### Flow 1: Create Campaign (Manual Entry)

**Step 1: Campaigns index page**
- Route: `/advertisers/:slug/campaigns`
- Shows list of campaigns (draft, scheduled, sent)
- Button: "Create Campaign"

**Step 2: New campaign form**
- Route: `/advertisers/:slug/campaigns/new`
- Fields:
  - Campaign Name (required)
  - Description (optional)
  - [Save as Draft] button → saves and redirects to edit page

**Step 3: Campaign edit page (draft)**
- Route: `/advertisers/:slug/campaigns/:id/edit`
- Tabs:
  1. **Recipients** (add manually or upload CSV)
  2. **Design** (select template, customize message)
  3. **Review & Send** (cost estimate, final review)

**Step 4: Add recipients (Tab 1)**

**Option A: Manual entry**
- Form to add one recipient at a time
- Fields: First name, Last name, Address, City, State, ZIP
- Optional: Company, Email, Phone
- "Validate Address" button (checks with Lob)
- "Add Recipient" → adds to campaign

**Option B: CSV Upload**
- Download sample CSV template
- Upload CSV file
- Preview recipients (show first 10)
- Validate all addresses (batch job)
- "Import X Recipients"

**Step 5: Choose template (Tab 2)**
- Grid of Lob templates with thumbnails
- Click to select
- Preview front/back
- Customize merge variables (if template has them)
- Optional: Add custom message text

**Step 6: Review & Send (Tab 3)**
- Summary:
  - Recipients: X postcards
  - Template: [thumbnail]
  - Estimated cost: $X.XX
- Button: "Calculate Cost" (if not already calculated)
- Button: "Send Now" → confirmation modal
- Button: "Save Draft" → saves and exits

**Step 7: Send confirmation modal**
```
Send X postcards?

Cost: $XX.XX
Expected delivery: 5-7 business days

This will charge your account and cannot be undone.

[Cancel] [Send Postcards]
```

**Step 8: Sending process**
- Status changes to "processing"
- Sidekiq job creates postcards via Lob API
- Progress indicator (optional: Turbo stream updates)
- Email notification when complete

**Step 9: Campaign sent view**
- Shows sent count, delivered count
- List of recipients with status
- Tracking info for each postcard

---

### Flow 2: Create Campaign (CSV Upload)

**CSV Format:**
```csv
first_name,last_name,company,address_line1,address_line2,city,state,zip,email,phone
John,Doe,Acme Corp,1234 Main St,,San Francisco,CA,94111,john@example.com,555-1234
Jane,Smith,,5678 Oak Ave,Apt 2,Los Angeles,CA,90001,jane@example.com,
```

**Upload process:**
1. User clicks "Upload CSV" on Recipients tab
2. File picker → selects CSV
3. Backend parses CSV
4. Validates format (required columns present)
5. Shows preview table (first 10 rows)
6. User confirms: "Import X recipients"
7. Background job:
   - Validates all addresses with Lob (batch)
   - Creates CampaignContact records
   - Marks invalid addresses (user can review/fix)
8. Redirects to Recipients tab with imported contacts
9. Show summary: "X imported, Y invalid (review below)"

**Error handling:**
- Invalid CSV format → show error with sample
- Missing required columns → list missing columns
- Invalid addresses → highlight in table, allow editing
- Duplicate addresses → option to skip or keep both

---

### Flow 3: Edit Draft Campaign

**Capabilities:**
- Change campaign name/description
- Add/remove recipients
- Change template
- Delete campaign
- Send campaign

**Restrictions:**
- Can only edit if status = 'draft'
- Once sent, campaign is read-only

---

### Flow 4: View Sent Campaign

**Route:** `/advertisers/:slug/campaigns/:id`

**Shows:**
- Campaign details (name, sent date, template)
- Stats: X sent, Y delivered, Z in transit
- Cost: estimated vs actual
- Recipient list with individual statuses
- Tracking info for each postcard

**Recipient detail modal:**
- Click recipient → shows modal
- Full address
- Status timeline (sent → in transit → delivered)
- Tracking number (link to USPS)
- Expected/actual delivery date
- Postcard preview (if available from Lob)

---

## Database Migrations

### Migration 1: Create campaigns table

```ruby
class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false  # enum
      
      t.string :template_id
      t.string :template_name
      t.string :template_thumbnail_url
      t.text :front_message
      t.text :back_message
      t.jsonb :merge_variables, default: {}
      
      t.integer :estimated_cost_cents, default: 0
      t.integer :actual_cost_cents, default: 0
      t.integer :recipient_count, default: 0
      t.integer :sent_count, default: 0
      t.integer :failed_count, default: 0
      t.integer :delivered_count, default: 0
      
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.datetime :completed_at
      
      t.timestamps
    end
    
    add_index :campaigns, [:advertiser_id, :status]
    add_index :campaigns, [:advertiser_id, :created_at]
    add_index :campaigns, :scheduled_at, where: "scheduled_at IS NOT NULL"
  end
end
```

---

### Migration 2: Create campaign_contacts table

```ruby
class CreateCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_contacts do |t|
      t.references :campaign, null: false, foreign_key: true
      
      # Recipient info
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :company
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :address_city, null: false
      t.string :address_state, null: false
      t.string :address_zip, null: false
      t.string :address_country, default: 'US'
      t.string :email
      t.string :phone
      t.jsonb :metadata, default: {}
      
      # Lob tracking
      t.string :lob_postcard_id
      t.integer :status, default: 0, null: false  # enum
      t.integer :estimated_cost_cents, default: 0
      t.integer :actual_cost_cents, default: 0
      t.string :tracking_number
      t.string :tracking_url
      t.date :expected_delivery_date
      t.datetime :delivered_at
      t.text :send_error
      t.jsonb :lob_response, default: {}
      
      t.timestamps
    end
    
    add_index :campaign_contacts, [:campaign_id, :status]
    add_index :campaign_contacts, [:campaign_id, :created_at]
    add_index :campaign_contacts, :lob_postcard_id, unique: true, where: "lob_postcard_id IS NOT NULL"
  end
end
```

---

## Models

### Campaign Model

```ruby
class Campaign < ApplicationRecord
  belongs_to :advertiser
  belongs_to :created_by_user, class_name: 'User'
  has_many :campaign_contacts, dependent: :destroy
  
  enum :status, {
    draft: 0,
    scheduled: 1,
    processing: 2,
    sent: 3,
    failed: 4,
    cancelled: 5
  }
  
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :advertiser_id, presence: true
  validates :created_by_user_id, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :scheduled_for_sending, -> { where(status: 'scheduled').where('scheduled_at <= ?', Time.current) }
  
  # Cost calculations
  def estimated_cost_dollars
    estimated_cost_cents / 100.0
  end
  
  def actual_cost_dollars
    actual_cost_cents / 100.0
  end
  
  def calculate_estimated_cost!
    return 0 if campaign_contacts.empty?
    
    # Fetch Lob pricing (6x9 postcard, first class)
    cost_per_postcard = 105 # cents ($1.05 per postcard)
    total = campaign_contacts.count * cost_per_postcard
    
    update!(estimated_cost_cents: total)
    campaign_contacts.update_all(estimated_cost_cents: cost_per_postcard)
    
    total
  end
  
  # State checks
  def sendable?
    draft? && recipient_count > 0 && template_id.present?
  end
  
  def deletable?
    draft?
  end
  
  def editable?
    draft?
  end
  
  # Actions
  def send_now!
    raise "Campaign not ready to send" unless sendable?
    
    update!(status: :processing, sent_at: Time.current)
    SendCampaignJob.perform_later(id)
  end
  
  def cancel!
    raise "Cannot cancel campaign in #{status} status" unless scheduled?
    
    update!(status: :cancelled)
  end
  
  # Stats
  def update_counts!
    update!(
      recipient_count: campaign_contacts.count,
      sent_count: campaign_contacts.where(status: [:sent, :in_transit, :delivered]).count,
      failed_count: campaign_contacts.where(status: :failed).count,
      delivered_count: campaign_contacts.where(status: :delivered).count
    )
  end
end
```

---

### CampaignContact Model

```ruby
class CampaignContact < ApplicationRecord
  belongs_to :campaign
  
  enum :status, {
    pending: 0,
    validating: 1,
    sending: 2,
    sent: 3,
    in_transit: 4,
    delivered: 5,
    returned: 6,
    failed: 7
  }
  
  validates :first_name, :last_name, presence: true
  validates :address_line1, :address_city, :address_state, :address_zip, presence: true
  validates :address_state, format: { with: /\A[A-Z]{2}\z/, message: "must be 2-letter state code" }
  validates :address_zip, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be valid ZIP code" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  scope :ready_to_send, -> { where(status: :pending) }
  scope :successfully_sent, -> { where(status: [:sent, :in_transit, :delivered]) }
  
  def full_name
    "#{first_name} #{last_name}".strip
  end
  
  def address_formatted
    lines = [
      full_name,
      company,
      address_line1,
      address_line2,
      "#{address_city}, #{address_state} #{address_zip}"
    ].compact.reject(&:blank?)
    
    lines.join("\n")
  end
  
  def cost_dollars
    actual_cost_cents / 100.0
  end
  
  def deliverable?
    !status.in?(['failed', 'returned'])
  end
  
  # Address validation with Lob
  def validate_address!
    update!(status: :validating)
    
    result = Lob::USVerification.verify(
      primary_line: address_line1,
      secondary_line: address_line2,
      city: address_city,
      state: address_state,
      zip_code: address_zip
    )
    
    if result.deliverability == 'deliverable'
      # Update with validated address
      update!(
        address_line1: result.primary_line,
        address_line2: result.secondary_line,
        address_city: result.components.city,
        address_state: result.components.state,
        address_zip: result.components.zip_code,
        status: :pending
      )
      true
    else
      update!(
        status: :failed,
        send_error: "Address not deliverable: #{result.deliverability}"
      )
      false
    end
  rescue => e
    update!(
      status: :failed,
      send_error: "Address validation failed: #{e.message}"
    )
    false
  end
end
```

---

## Services & Jobs

### LobClient Service

```ruby
# app/services/lob_client.rb
class LobClient
  class << self
    def create_postcard(campaign_contact:, campaign:, from_address:)
      postcard = Lob::Postcard.create(
        description: "Campaign: #{campaign.name} - #{campaign_contact.full_name}",
        to: {
          name: campaign_contact.full_name,
          company: campaign_contact.company,
          address_line1: campaign_contact.address_line1,
          address_line2: campaign_contact.address_line2,
          address_city: campaign_contact.address_city,
          address_state: campaign_contact.address_state,
          address_zip: campaign_contact.address_zip,
          address_country: campaign_contact.address_country
        },
        from: from_address,
        front: campaign.template_id,
        back: campaign.back_message || campaign.template_id,
        merge_variables: campaign.merge_variables.merge(
          first_name: campaign_contact.first_name,
          last_name: campaign_contact.last_name
        ),
        size: "6x9",
        mail_type: "usps_first_class",
        metadata: {
          campaign_id: campaign.id,
          campaign_contact_id: campaign_contact.id,
          advertiser_id: campaign.advertiser_id
        }
      )
      
      postcard
    end
    
    def get_postcard(lob_postcard_id)
      Lob::Postcard.retrieve(lob_postcard_id)
    end
    
    def list_templates
      Lob::Template.list(limit: 50)
    end
    
    def verify_address(address_line1:, city:, state:, zip:, address_line2: nil)
      Lob::USVerification.verify(
        primary_line: address_line1,
        secondary_line: address_line2,
        city: city,
        state: state,
        zip_code: zip
      )
    end
  end
end
```

---

### SendCampaignJob

```ruby
# app/jobs/send_campaign_job.rb
class SendCampaignJob < ApplicationJob
  queue_as :default
  
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    advertiser = campaign.advertiser
    
    # Get advertiser's return address
    from_address = {
      name: advertiser.name,
      address_line1: advertiser.street_address,
      address_city: advertiser.city,
      address_state: advertiser.state,
      address_zip: advertiser.postal_code,
      address_country: advertiser.country
    }
    
    sent_count = 0
    failed_count = 0
    total_cost = 0
    
    campaign.campaign_contacts.ready_to_send.find_each do |contact|
      begin
        contact.update!(status: :sending)
        
        postcard = LobClient.create_postcard(
          campaign_contact: contact,
          campaign: campaign,
          from_address: from_address
        )
        
        contact.update!(
          lob_postcard_id: postcard.id,
          status: :sent,
          tracking_number: postcard.tracking_number,
          tracking_url: postcard.url,
          expected_delivery_date: postcard.expected_delivery_date,
          actual_cost_cents: (postcard.price.to_f * 100).to_i,
          lob_response: postcard.to_h
        )
        
        sent_count += 1
        total_cost += contact.actual_cost_cents
        
      rescue => e
        contact.update!(
          status: :failed,
          send_error: e.message
        )
        failed_count += 1
        
        Rails.logger.error "Failed to send postcard for campaign_contact #{contact.id}: #{e.message}"
      end
      
      # Rate limiting: Lob allows ~100 req/sec, but be conservative
      sleep 0.1
    end
    
    # Update campaign
    campaign.update!(
      status: :sent,
      completed_at: Time.current,
      sent_count: sent_count,
      failed_count: failed_count,
      actual_cost_cents: total_cost
    )
    
    # Send completion email
    CampaignMailer.campaign_sent(campaign).deliver_later
    
  rescue => e
    campaign.update!(status: :failed)
    Rails.logger.error "Campaign #{campaign_id} failed: #{e.message}"
    raise
  end
end
```

---

### UpdatePostcardStatusesJob (Scheduled)

```ruby
# app/jobs/update_postcard_statuses_job.rb
class UpdatePostcardStatusesJob < ApplicationJob
  queue_as :default
  
  # Run daily via Sidekiq cron to update delivery statuses
  def perform
    CampaignContact.where(status: [:sent, :in_transit])
                   .where.not(lob_postcard_id: nil)
                   .find_each do |contact|
      begin
        postcard = LobClient.get_postcard(contact.lob_postcard_id)
        
        new_status = map_lob_status(postcard.status)
        
        contact.update!(
          status: new_status,
          delivered_at: (postcard.send_date if new_status == 'delivered'),
          lob_response: postcard.to_h
        )
        
        # Update campaign counts if status changed
        contact.campaign.update_counts!
        
      rescue => e
        Rails.logger.error "Failed to update postcard status for #{contact.id}: #{e.message}"
      end
      
      sleep 0.1 # Rate limiting
    end
  end
  
  private
  
  def map_lob_status(lob_status)
    case lob_status
    when 'in_transit' then 'in_transit'
    when 'in local area' then 'in_transit'
    when 'processed for delivery' then 'in_transit'
    when 'delivered' then 'delivered'
    when 'returned' then 'returned'
    else 'sent'
    end
  end
end
```

---

## CSV Import

### CsvImporter Service

```ruby
# app/services/csv_importer.rb
class CsvImporter
  attr_reader :campaign, :file, :errors
  
  def initialize(campaign:, file:)
    @campaign = campaign
    @file = file
    @errors = []
  end
  
  def import
    require 'csv'
    
    rows = CSV.parse(file.read, headers: true)
    
    validate_headers(rows.headers)
    return false if @errors.any?
    
    imported_count = 0
    invalid_count = 0
    
    rows.each_with_index do |row, index|
      contact = campaign.campaign_contacts.build(
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
      
      if contact.valid?
        contact.save!
        imported_count += 1
      else
        invalid_count += 1
        @errors << "Row #{index + 2}: #{contact.errors.full_messages.join(', ')}"
      end
    end
    
    campaign.update_counts!
    
    {
      imported: imported_count,
      invalid: invalid_count,
      errors: @errors
    }
  rescue CSV::MalformedCSVError => e
    @errors << "Invalid CSV format: #{e.message}"
    false
  end
  
  private
  
  def validate_headers(headers)
    required = %w[first_name last_name address_line1 city state zip]
    missing = required - headers.map(&:downcase)
    
    if missing.any?
      @errors << "Missing required columns: #{missing.join(', ')}"
    end
  end
end
```

---

## Controllers

### CampaignsController

```ruby
# app/controllers/campaigns_controller.rb
class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :send_now, :calculate_cost]
  
  def index
    @campaigns = @advertiser.campaigns.recent.page(params[:page])
  end
  
  def show
    @campaign_contacts = @campaign.campaign_contacts.page(params[:page])
  end
  
  def new
    @campaign = @advertiser.campaigns.build
  end
  
  def create
    @campaign = @advertiser.campaigns.build(campaign_params)
    @campaign.created_by_user = current_user
    
    if @campaign.save
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign), 
                  notice: 'Campaign created. Add recipients to continue.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    # Tabbed interface: recipients, design, review
  end
  
  def update
    if @campaign.update(campaign_params)
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign), 
                  notice: 'Campaign updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    unless @campaign.deletable?
      redirect_to advertiser_campaigns_path(@advertiser), 
                  alert: 'Cannot delete campaign that has been sent.'
      return
    end
    
    @campaign.destroy
    redirect_to advertiser_campaigns_path(@advertiser), 
                notice: 'Campaign deleted.'
  end
  
  def calculate_cost
    @campaign.calculate_estimated_cost!
    redirect_to edit_advertiser_campaign_path(@advertiser, @campaign, tab: 'review'),
                notice: "Estimated cost: #{number_to_currency(@campaign.estimated_cost_dollars)}"
  end
  
  def send_now
    unless @campaign.sendable?
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign),
                  alert: 'Campaign not ready to send. Add recipients and select a template.'
      return
    end
    
    @campaign.send_now!
    redirect_to advertiser_campaign_path(@advertiser, @campaign),
                notice: 'Campaign is being sent. You will receive an email when complete.'
  end
  
  private
  
  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end
  
  def set_campaign
    @campaign = @advertiser.campaigns.find(params[:id])
  end
  
  def campaign_params
    params.require(:campaign).permit(
      :name, :description, :template_id, :template_name, 
      :template_thumbnail_url, :front_message, :back_message,
      merge_variables: {}
    )
  end
end
```

---

### CampaignContactsController

```ruby
# app/controllers/campaign_contacts_controller.rb
class CampaignContactsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_advertiser
  before_action :set_campaign
  
  def create
    @contact = @campaign.campaign_contacts.build(contact_params)
    
    if @contact.save
      # Optionally validate address
      @contact.validate_address! if params[:validate_address]
      
      @campaign.update_counts!
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign, tab: 'recipients'),
                  notice: 'Recipient added.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    @contact = @campaign.campaign_contacts.find(params[:id])
    @contact.destroy
    
    @campaign.update_counts!
    redirect_to edit_advertiser_campaign_path(@advertiser, @campaign, tab: 'recipients'),
                notice: 'Recipient removed.'
  end
  
  def import_csv
    file = params[:csv_file]
    
    unless file.present?
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign, tab: 'recipients'),
                  alert: 'Please select a CSV file.'
      return
    end
    
    importer = CsvImporter.new(campaign: @campaign, file: file)
    result = importer.import
    
    if result[:imported] > 0
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign, tab: 'recipients'),
                  notice: "Imported #{result[:imported]} recipients. #{result[:invalid]} invalid."
    else
      redirect_to edit_advertiser_campaign_path(@advertiser, @campaign, tab: 'recipients'),
                  alert: "Import failed: #{importer.errors.join(', ')}"
    end
  end
  
  private
  
  def set_advertiser
    @advertiser = current_user.advertisers.find_by!(slug: params[:advertiser_slug])
  end
  
  def set_campaign
    @campaign = @advertiser.campaigns.find(params[:campaign_id])
  end
  
  def contact_params
    params.require(:campaign_contact).permit(
      :first_name, :last_name, :company,
      :address_line1, :address_line2, :address_city, 
      :address_state, :address_zip, :email, :phone
    )
  end
end
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # ... existing routes ...
  
  resources :advertisers, param: :slug do
    resources :campaigns do
      member do
        post :send_now
        post :calculate_cost
        post :cancel  # Post-MVP: for scheduled campaigns
      end
      
      resources :campaign_contacts, only: [:create, :destroy] do
        collection do
          post :import_csv
        end
      end
    end
  end
end
```

---

## UI Components

### Campaigns Index Page

**Route:** `/advertisers/:slug/campaigns`

```
┌─────────────────────────────────────────────────────────────┐
│ Campaigns                                    [Create Campaign]│
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ Filters: [All] [Drafts] [Sent] [Scheduled]                  │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│ Summer Sale 2024                                    📝 Draft  │
│ Created 2 hours ago • 0 recipients                           │
│ [Continue Editing]                              [Delete]     │
├─────────────────────────────────────────────────────────────┤
│ Spring Promotion                                   ✅ Sent   │
│ Sent Mar 15, 2024 • 1,234 postcards • $1,296.70             │
│ 1,150 delivered • 80 in transit • 4 returned                │
│ [View Details]                                               │
├─────────────────────────────────────────────────────────────┤
│ Holiday Cards 2023                                 ✅ Sent   │
│ Sent Dec 1, 2023 • 567 postcards • $595.35                  │
│ 565 delivered • 2 returned                                   │
│ [View Details]                                               │
└─────────────────────────────────────────────────────────────┘
```

---

### Campaign Edit Page (Tabbed)

**Route:** `/advertisers/:slug/campaigns/:id/edit`

```
┌─────────────────────────────────────────────────────────────┐
│ ← Back to Campaigns                                          │
│                                                               │
│ Summer Sale 2024                              Status: Draft  │
│                                                               │
│ [Recipients] [Design] [Review & Send]                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ TAB: Recipients                                              │
│ ─────────────────────────────────────────────────────────────│
│                                                               │
│ [Add Manually] [Upload CSV] [Download CSV Template]         │
│                                                               │
│ 0 recipients added                                           │
│                                                               │
│ ┌──────────────────────────────────────────────────────────┐│
│ │ Upload CSV File                                           ││
│ │                                                           ││
│ │ [Choose File]  No file chosen                            ││
│ │                                                           ││
│ │ [Upload]                                                  ││
│ │                                                           ││
│ │ Required columns: first_name, last_name, address_line1,  ││
│ │ city, state, zip                                          ││
│ └──────────────────────────────────────────────────────────┘│
│                                                               │
│ ┌──────────────────────────────────────────────────────────┐│
│ │ Add Recipient Manually                                    ││
│ │                                                           ││
│ │ First Name: [_____________]  Last Name: [_____________]  ││
│ │ Company: [_____________]                                  ││
│ │                                                           ││
│ │ Address Line 1: [____________________________________]   ││
│ │ Address Line 2: [____________________________________]   ││
│ │ City: [_____________]  State: [__]  ZIP: [_______]      ││
│ │                                                           ││
│ │ Email: [_____________]  Phone: [_____________]           ││
│ │                                                           ││
│ │ [✓ Validate Address]  [Add Recipient]                    ││
│ └──────────────────────────────────────────────────────────┘│
│                                                               │
│ [Save Draft]                                      [Continue →]│
└─────────────────────────────────────────────────────────────┘
```

---

### Design Tab

```
┌─────────────────────────────────────────────────────────────┐
│ TAB: Design                                                  │
│ ─────────────────────────────────────────────────────────────│
│                                                               │
│ Choose Postcard Template                                     │
│                                                               │
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                        │
│ │[img] │ │[img] │ │[img] │ │[img] │                        │
│ │Sale  │ │Event │ │Thank │ │Blank │                        │
│ └──────┘ └──────┘ └──────┘ └──────┘                        │
│   ✓                                                          │
│                                                               │
│ Template: "Sale Announcement"                                │
│ Size: 6x9 inches                                             │
│                                                               │
│ Customize Message                                            │
│ ─────────────────────────────────────────────────────────────│
│                                                               │
│ Front Message (optional):                                    │
│ [_________________________________________________________]  │
│ [_________________________________________________________]  │
│                                                               │
│ Back Message (optional):                                     │
│ [_________________________________________________________]  │
│ [_________________________________________________________]  │
│ [_________________________________________________________]  │
│                                                               │
│ Available variables: {{first_name}}, {{last_name}}          │
│                                                               │
│ [← Back]  [Save Draft]                          [Continue →] │
└─────────────────────────────────────────────────────────────┘
```

---

### Review & Send Tab

```
┌─────────────────────────────────────────────────────────────┐
│ TAB: Review & Send                                           │
│ ─────────────────────────────────────────────────────────────│
│                                                               │
│ Campaign Summary                                             │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                               │
│ Recipients:        1,234 postcards                           │
│ Template:          Sale Announcement (6x9)                   │
│                                                               │
│ ┌──────┐                                                     │
│ │[img] │ Preview                                             │
│ └──────┘                                                     │
│                                                               │
│ Cost Estimate                                                │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                               │
│ 1,234 postcards × $1.05            $1,295.70                │
│                                                               │
│ Total:                              $1,295.70                │
│                                                               │
│ [Recalculate Cost]                                           │
│                                                               │
│ Expected delivery: 5-7 business days from send date         │
│                                                               │
│ [← Back]  [Save Draft]                          [Send Now →] │
└─────────────────────────────────────────────────────────────┘
```

---

### Send Confirmation Modal

```
┌─────────────────────────────────────────────────────────────┐
│ Send 1,234 postcards?                                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ Cost: $1,295.70                                              │
│ Expected delivery: 5-7 business days                         │
│                                                               │
│ This will charge your Lob account and cannot be undone.     │
│                                                               │
│ [Cancel]                                    [Send Postcards] │
└─────────────────────────────────────────────────────────────┘
```

---

### Sent Campaign View

**Route:** `/advertisers/:slug/campaigns/:id`

```
┌─────────────────────────────────────────────────────────────┐
│ ← Back to Campaigns                                          │
│                                                               │
│ Summer Sale 2024                               Status: Sent  │
│ Sent: May 15, 2024 at 2:30 PM                               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ Campaign Stats                                               │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                               │
│ 📬 1,234 Total Postcards                                     │
│ ✅ 1,150 Delivered                                           │
│ 🚚 80 In Transit                                             │
│ ❌ 4 Returned                                                │
│                                                               │
│ Cost                                                         │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                               │
│ Estimated: $1,295.70                                         │
│ Actual:    $1,295.70                                         │
│                                                               │
│ Recipients                                                   │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                               │
│ [Search recipients...] [Export CSV] [Filter: All ▼]         │
│                                                               │
│ John Doe                                         ✅ Delivered │
│ 1234 Main St, San Francisco, CA 94111                       │
│ Expected: May 20 • Delivered: May 19                        │
│ [View Details]                                               │
│ ─────────────────────────────────────────────────────────────│
│ Jane Smith                                      🚚 In Transit │
│ 5678 Oak Ave, Los Angeles, CA 90001                         │
│ Expected: May 22                                             │
│ [Track]                                                      │
│ ─────────────────────────────────────────────────────────────│
│ Bob Johnson                                      ❌ Returned  │
│ 999 Elm St, Chicago, IL 60601                               │
│ Reason: Invalid address                                     │
│ ─────────────────────────────────────────────────────────────│
│                                                               │
│ [1] [2] [3] ... [42]                                         │
└─────────────────────────────────────────────────────────────┘
```

---

### Recipient Detail Modal

```
┌─────────────────────────────────────────────────────────────┐
│ Postcard Details                                        [×]  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ John Doe                                                     │
│ Acme Corp                                                    │
│ 1234 Main St                                                 │
│ San Francisco, CA 94111                                      │
│                                                               │
│ Status: Delivered ✅                                         │
│                                                               │
│ Timeline                                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│
│                                                               │
│ ✓ May 15, 2:30 PM    Sent to Lob                           │
│ ✓ May 16, 10:00 AM   In production                         │
│ ✓ May 17, 2:00 PM    In transit (USPS)                     │
│ ✓ May 19, 11:23 AM   Delivered                             │
│                                                               │
│ Tracking: 9400111899223344556677                            │
│ [View USPS Tracking →]                                       │
│                                                               │
│ Cost: $1.05                                                  │
│                                                               │
│ [Close]                                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Email Notifications

### Campaign Sent (Success)

**Trigger:** Campaign completes sending

**Recipients:** Campaign creator

**Subject:** "Your postcard campaign has been sent"

**Content:**
```
Your campaign "Summer Sale 2024" has been sent!

Results:
• 1,234 postcards sent
• 4 failed to send
• Total cost: $1,295.70

Expected delivery: 5-7 business days

Your postcards are on their way! Track delivery status in your dashboard.

[View Campaign]
```

---

### Campaign Failed

**Trigger:** Campaign fails to send

**Recipients:** Campaign creator + advertiser admins

**Subject:** "Action needed: Campaign failed to send"

**Content:**
```
Your campaign "Summer Sale 2024" failed to send.

Error: [error message]

Your account has not been charged. Please review the campaign and try again.

[View Campaign] [Contact Support]
```

---

## Post-MVP: Scheduling

### Database Changes

Add scheduling fields (already in schema):
- `scheduled_at` (timestamp)
- Status enum: add `scheduled`

### UI Changes

**Review & Send tab:**
```
[Send Now] [Schedule for Later]
```

**Schedule modal:**
```
┌─────────────────────────────────────────────────────────────┐
│ Schedule Campaign                                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│ Send Date: [_____/_____/_____]  Time: [__:__ AM/PM]        │
│            MM    DD    YYYY          Timezone: PST           │
│                                                               │
│ Postcards will be sent on this date at this time.           │
│ You can cancel or reschedule anytime before then.           │
│                                                               │
│ [Cancel]                                            [Schedule]│
└─────────────────────────────────────────────────────────────┘
```

**Scheduled campaigns index:**
```
┌─────────────────────────────────────────────────────────────┐
│ Holiday Sale                             📅 Scheduled: Dec 1  │
│ Created Oct 15 • 2,500 recipients • Est. $2,625.00          │
│ [Edit] [Cancel] [Reschedule]                                │
└─────────────────────────────────────────────────────────────┘
```

### Backend Changes

**Sidekiq cron job:**
```ruby
# config/initializers/sidekiq.rb
schedule_file = "config/schedule.yml"

if File.exist?(schedule_file)
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end
```

**config/schedule.yml:**
```yaml
send_scheduled_campaigns:
  cron: "*/5 * * * *"  # Every 5 minutes
  class: "SendScheduledCampaignsJob"
```

**SendScheduledCampaignsJob:**
```ruby
class SendScheduledCampaignsJob < ApplicationJob
  def perform
    Campaign.scheduled_for_sending.find_each do |campaign|
      campaign.send_now!
    end
  end
end
```

---

## Implementation Timeline

### Week 1: Core Models & Lob Integration (Days 1-5)

**Day 1: Setup & Models**
- Add `lob` gem
- Create migrations: campaigns, campaign_contacts
- Create models with validations
- Test: can create campaign and add recipients

**Day 2: Lob API Integration**
- Create LobClient service
- Test address verification
- Test postcard creation (test mode)
- Test template listing
- Configure API keys

**Day 3: Campaign Flow (Backend)**
- SendCampaignJob implementation
- Cost calculation logic
- Error handling and retries
- Test: can send test campaign with 10 recipients

**Day 4: CSV Import**
- CsvImporter service
- Validation and error handling
- Test: can import 100+ recipients from CSV
- Generate sample CSV template

**Day 5: Status Tracking**
- UpdatePostcardStatusesJob
- Webhook endpoint for Lob (if available)
- Test: statuses update correctly

---

### Week 2: UI & Controllers (Days 1-5)

**Day 1: Campaigns Index & CRUD**
- CampaignsController
- Index, new, create actions
- Basic views
- Test: user can create campaign via UI

**Day 2: Campaign Edit (Recipients Tab)**
- Manual recipient form
- CSV upload UI
- Recipients list display
- Test: user can add recipients both ways

**Day 3: Campaign Edit (Design Tab)**
- Template selection UI
- Message customization
- Preview functionality
- Test: user can select template

**Day 4: Campaign Edit (Review & Send)**
- Cost calculation UI
- Summary display
- Send confirmation modal
- Test: user can send campaign

**Day 5: Campaign View (Sent)**
- Sent campaign details page
- Recipient list with statuses
- Tracking info display
- Test: user can view sent campaign details

---

### Week 3: Polish & Testing (Days 1-3)

**Day 1: Email Notifications**
- Campaign sent email
- Campaign failed email
- Integration with LoopsClient
- Test: emails send correctly

**Day 2: Error Handling & Validation**
- Address validation UI
- Error messages for failed sends
- Retry logic for API failures
- Test: edge cases handled gracefully

**Day 3: Integration Testing**
- Test with real Lob test account
- Test large campaigns (100+ recipients)
- Test CSV imports with errors
- Load testing

---

## Success Criteria

### MVP Complete When:

- [ ] User can create campaign with name/description
- [ ] User can save campaign as draft
- [ ] User can add recipients manually (one at a time)
- [ ] User can upload recipients via CSV
- [ ] CSV validation works (required fields, format)
- [ ] User can select Lob template
- [ ] Cost estimation calculates correctly
- [ ] User can send campaign (1-1000 recipients)
- [ ] Postcards created in Lob successfully
- [ ] Send status tracked per recipient
- [ ] User can view sent campaign with delivery statuses
- [ ] Draft campaigns can be deleted
- [ ] Sent campaigns cannot be deleted/edited
- [ ] Email notifications sent on completion
- [ ] Error handling for failed sends
- [ ] Works in Lob test mode (development)
- [ ] Works in Lob live mode (production)
- [ ] All data scoped to advertiser (no cross-tenant leaks)
- [ ] Performance acceptable (100 postcards created in <2 minutes)

---

## Post-MVP Roadmap

### Phase 2: Scheduling (1 week)
- Schedule campaigns for future dates
- Cancel/reschedule functionality
- Cron job to process scheduled campaigns
- Email reminders before send

### Phase 3: Custom Templates (1-2 weeks)
- Upload custom PDF designs
- HTML template builder (basic)
- Template library per advertiser
- Preview rendering

### Phase 4: Shopify Integration (from existing spec)
- Link campaigns to Shopify contacts
- Segment builder (RFM, tags, etc.)
- Send to filtered contact lists
- No manual entry needed

### Phase 5: Automation & Triggers (2-3 weeks)
- Automated postcards on events (new customer, birthday, etc.)
- Abandoned cart postcards
- Win-back campaigns
- Multi-step sequences

### Phase 6: Analytics & Reporting (1-2 weeks)
- Campaign performance dashboard
- Delivery rate trends
- Cost per delivery
- ROI tracking (if linked to sales)

### Phase 7: Advanced Features
- A/B testing (multiple templates)
- Personalized images (variable data printing)
- International mail support
- Bulk discount negotiation with Lob

---

## Budget Considerations

### Lob Costs (as of 2024)

**Per postcard:**
- 6x9 postcard: ~$1.05 (USPS First Class)
- 100 postcards = $105
- 1,000 postcards = $1,050
- 10,000 postcards = $10,500

**Volume discounts:**
- Available at higher volumes (contact Lob)
- Typically start at 10K+/month

**Test mode:**
- Free for development
- No actual mail sent
- Unlimited testing

### Pricing Strategy for Users

**Options:**

**Option A: Pass-through pricing**
- Charge users exact Lob cost
- Simplest to implement
- User pays $1.05/postcard

**Option B: Markup**
- Charge users $1.25-$1.50/postcard
- Platform earns $0.20-$0.45/postcard
- Covers platform costs + margin

**Option C: Subscription + discounted postcards**
- Monthly platform fee ($99-$299)
- Postcards at cost or small markup
- Predictable revenue for platform

**Recommendation for MVP:**
- Start with Option A (pass-through)
- Add pricing markup post-MVP once value proven
- Offer volume discounts later

---

## Testing Strategy

### Test Scenarios

**1. Happy path:**
- Create campaign
- Add 5 recipients manually
- Select template
- Calculate cost
- Send campaign
- Verify postcards created in Lob
- Check statuses update

**2. CSV import:**
- Upload valid CSV with 50 recipients
- Verify all imported
- Upload CSV with errors
- Verify error handling

**3. Address validation:**
- Add invalid address
- Verify validation fails
- Correct address
- Verify validation succeeds

**4. Cost calculation:**
- Campaign with 100 recipients
- Verify cost = 100 × $1.05 = $105.00

**5. Send failures:**
- Mock Lob API error
- Verify retry logic
- Verify error recorded
- Verify email notification

**6. Large campaigns:**
- Campaign with 1,000 recipients
- Verify rate limiting
- Verify all sent successfully
- Verify total cost accurate

**7. Draft management:**
- Create draft
- Edit draft
- Delete draft
- Verify cannot delete sent campaign

**8. Multi-tenant isolation:**
- User A creates campaign
- User B from different advertiser
- Verify User B cannot see User A's campaign

---

## Security Considerations

### API Key Storage

**Lob API keys:**
- Store in Rails credentials (encrypted)
- Never commit to git
- Separate test/live keys
- Rotate keys periodically

```ruby
# config/credentials.yml.enc
lob:
  test_api_key: test_abc123...
  live_api_key: live_xyz789...
```

### Authorization

**Campaign access:**
- Users can only access campaigns for their advertiser
- Use `current_user.advertisers` scope
- Verify advertiser membership on every request

**Cost protection:**
- Confirm before sending (no auto-send)
- Show estimated cost prominently
- Require explicit "Send" action
- Log all sends for audit

### PII Handling

**Recipient data:**
- Stored in database (encrypted at rest)
- Address data sent to Lob API
- Compliant with Lob's terms of service
- Allow advertiser to delete campaigns (GDPR)

**Data retention:**
- Keep sent campaigns indefinitely (business records)
- Allow campaign deletion if requested (GDPR right to erasure)
- Delete associated recipients when campaign deleted

---

## Monitoring & Logging

### Key Metrics to Track

**Campaign metrics:**
- Campaigns created per day/week/month
- Campaigns sent vs drafted (conversion rate)
- Average recipients per campaign
- Total postcards sent

**Cost metrics:**
- Total spend per advertiser
- Total spend across platform
- Average cost per campaign
- Lob API errors (rate limits, etc.)

**Performance metrics:**
- Campaign send duration (time to process all postcards)
- API response times
- Background job queue depth
- Failed job rate

**User behavior:**
- CSV imports vs manual entry
- Most popular templates
- Average time from draft to send
- Campaign deletion rate

### Logging

**Log events:**
- Campaign created
- Recipients added (count)
- Campaign sent (start)
- Postcards created (count)
- Campaign completed (stats)
- API errors
- Failed sends

**Use Rails logger:**
```ruby
Rails.logger.info "Campaign #{campaign.id} sent: #{sent_count} postcards, $#{total_cost}"
Rails.logger.error "Failed to create postcard: #{error.message}"
```

---

## Conclusion

This Lob.com postcard MVP provides:

- **Simple campaign creation** with draft management
- **Flexible recipient management** (manual + CSV upload)
- **Cost transparency** with real-time estimation
- **Reliable sending** via Lob API with error handling
- **Status tracking** for delivery visibility
- **Clean, intuitive UI** inspired by modern SaaS apps
- **Foundation for future features** (scheduling, Shopify integration, automation)

**Timeline: 2-3 weeks to production MVP**

Combined with your Shopify integration (3-4 weeks), you'll have a complete direct mail marketing platform integrated with e-commerce data in under 2 months.

Ready to build? 🚀

