# Attribution & Performance Tracking Specification

**Date**: October 7, 2025  
**Status**: Specification / Not Implemented  
**Priority**: 🔴 CRITICAL for customer value

---

## Executive Summary

This document outlines the **attribution and performance tracking system** for Nurture. Without attribution, customers cannot prove ROI from their postcard campaigns, making the platform a commodity service rather than a valuable marketing tool.

**The Core Problem**:
```
Current state:
1. Send postcard ✅
2. Lob delivers it ✅
3. Customer receives it ❓
4. Customer acts on it ❓❓❓
5. Did it drive revenue? ❓❓❓❓❓

BLIND SPOT: No way to prove value or optimize campaigns
```

**The Solution**: Multi-tiered attribution system that tracks conversions through multiple methods, from simple (promo codes) to sophisticated (identity resolution).

---

## Table of Contents

1. [Attribution Tiers Overview](#attribution-tiers-overview)
2. [Tier 1: Shopify Transaction Matching](#tier-1-shopify-transaction-matching)
3. [Tier 2: QR Code Tracking](#tier-2-qr-code-tracking)
4. [Tier 3: Identity Resolution](#tier-3-identity-resolution)
5. [Analytics Dashboard](#analytics-dashboard)
6. [Dry Run Mode (Testing)](#dry-run-mode-testing)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Success Metrics](#success-metrics)

---

## Attribution Tiers Overview

### Complexity vs. Value Matrix

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  HIGH VALUE ↑                                   │
│             │                                   │
│             │  Tier 3: Identity Resolution      │
│             │  (Most powerful, 30-40 hours)     │
│             │                                   │
│             │  Tier 2: QR Code Tracking         │
│             │  (Good signal, 10-14 hours)       │
│             │                                   │
│             │  Tier 1: Transaction Matching     │
│             │  (Direct signal, 8-12 hours)      │
│             │                                   │
│  LOW VALUE  └──────────────────────────→        │
│                              LOW → HIGH EFFORT  │
└─────────────────────────────────────────────────┘
```

### Attribution Methods Comparison

| Method | Signal Strength | Implementation | Customer Friction | Recommended Priority |
|--------|----------------|----------------|-------------------|---------------------|
| **Unique Promo Codes** | 🟢 Strong | 🟢 Easy | 🟡 Medium | 1️⃣ Build first |
| **QR Code Scans** | 🟡 Medium | 🟡 Medium | 🟢 Low | 2️⃣ Build second |
| **Delivery Window** | 🔴 Weak | 🟢 Easy | 🟢 None | 3️⃣ Fallback only |
| **Identity Resolution** | 🟢 Strong | 🔴 Hard | 🟢 None | 4️⃣ Build later |

---

## Tier 1: Shopify Transaction Matching

### Overview

**Priority**: 🔴 **BUILD FIRST** (Week 1)  
**Time Estimate**: 8-12 hours  
**Value**: Direct, accurate attribution with minimal ambiguity

**What it tracks**:
- Direct conversions (customer used promo code)
- Revenue per postcard
- Time to conversion (delivery → purchase)
- Cost per acquisition
- Return on ad spend (ROAS)

**How it works**:
```
1. Generate unique promo code per postcard (e.g., ACME-A3F9B2)
2. Print code on postcard: "Use code ACME-A3F9B2 for 15% off"
3. Customer receives postcard → shops → uses code at checkout
4. Shopify order webhook fires → match discount code → attribute sale
5. Track revenue, calculate ROAS
```

### Database Schema

```ruby
# db/migrate/xxx_add_attribution_to_campaign_contacts.rb
class AddAttributionToCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    # Promo code tracking
    add_column :campaign_contacts, :unique_promo_code, :string
    add_column :campaign_contacts, :redemption_count, :integer, default: 0
    add_column :campaign_contacts, :attributed_revenue, :decimal, precision: 10, scale: 2, default: 0
    add_column :campaign_contacts, :first_conversion_at, :datetime
    add_column :campaign_contacts, :last_conversion_at, :datetime
    add_column :campaign_contacts, :attributed_order_ids, :jsonb, default: []
    
    # Indexes for performance
    add_index :campaign_contacts, :unique_promo_code, unique: true
    add_index :campaign_contacts, [:campaign_id, :redemption_count]
    add_index :campaign_contacts, :first_conversion_at
  end
end

# db/migrate/xxx_add_attribution_to_campaigns.rb
class AddAttributionToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :promo_code_prefix, :string
    add_column :campaigns, :conversion_count, :integer, default: 0
    add_column :campaigns, :attributed_revenue, :decimal, precision: 10, scale: 2, default: 0
    add_column :campaigns, :roas, :decimal, precision: 5, scale: 2, default: 0
    
    add_index :campaigns, [:advertiser_id, :conversion_count]
  end
end

# db/migrate/xxx_add_discount_codes_to_orders.rb
class AddDiscountCodesToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :discount_codes, :jsonb, default: []
    add_index :orders, :discount_codes, using: :gin
  end
end
```

### Model Implementation

```ruby
# app/models/campaign_contact.rb
class CampaignContact < ApplicationRecord
  belongs_to :campaign
  belongs_to :contact, optional: true
  
  # Generate unique promo code on creation
  before_create :generate_promo_code
  
  # Track conversion from order
  def track_conversion(order)
    return if attributed_order_ids.include?(order.id)
    
    increment!(:redemption_count)
    self.attributed_revenue += order.total_price.to_f
    self.first_conversion_at ||= Time.current
    self.last_conversion_at = Time.current
    self.attributed_order_ids << order.id
    save!
    
    # Update campaign-level stats
    campaign.update_attribution_stats!
    
    Rails.logger.info "[Attribution] Order #{order.order_number} attributed to Campaign #{campaign.id} via promo code #{unique_promo_code}"
  end
  
  # Days from delivery to conversion
  def time_to_conversion
    return nil unless first_conversion_at && delivered_at
    (first_conversion_at - delivered_at) / 1.day
  end
  
  private
  
  def generate_promo_code
    # Use campaign prefix or generate from advertiser name
    prefix = campaign.promo_code_prefix || 
             campaign.advertiser.name.parameterize.upcase.first(5)
    
    # Generate unique code
    loop do
      code = "#{prefix}#{SecureRandom.hex(3).upcase}"
      unless CampaignContact.exists?(unique_promo_code: code)
        self.unique_promo_code = code
        break
      end
    end
  end
end
```

```ruby
# app/models/campaign.rb
class Campaign < ApplicationRecord
  # Attribution analytics
  def attribution_stats
    {
      total_conversions: campaign_contacts.where('redemption_count > 0').count,
      conversion_rate: (campaign_contacts.where('redemption_count > 0').count.to_f / recipient_count * 100).round(2),
      total_revenue: campaign_contacts.sum(:attributed_revenue).to_f,
      avg_order_value: campaign_contacts.where('redemption_count > 0').average(:attributed_revenue)&.to_f&.round(2) || 0,
      cost_per_acquisition: conversion_count > 0 ? (actual_cost_dollars / conversion_count).round(2) : 0,
      roas: actual_cost_dollars > 0 ? (campaign_contacts.sum(:attributed_revenue) / actual_cost_dollars).round(2) : 0,
      avg_time_to_conversion: campaign_contacts.where.not(first_conversion_at: nil)
                                               .average('EXTRACT(EPOCH FROM (first_conversion_at - delivered_at)) / 86400')
                                               &.round(1) || 0
    }
  end
  
  def update_attribution_stats!
    stats = attribution_stats
    update_columns(
      conversion_count: stats[:total_conversions],
      attributed_revenue: stats[:total_revenue],
      roas: stats[:roas]
    )
  end
  
  # Top performing segments
  def segment_performance
    campaign_contacts
      .joins(:contact)
      .where.not('contacts.rfm_segment' => [nil, ''])
      .group('contacts.rfm_segment')
      .select(
        'contacts.rfm_segment',
        'COUNT(*) as sent_count',
        'SUM(campaign_contacts.redemption_count) as conversions',
        'SUM(campaign_contacts.attributed_revenue) as revenue',
        'AVG(campaign_contacts.attributed_revenue) as avg_order_value'
      )
      .order('revenue DESC')
  end
end
```

### Shopify Order Webhook

```ruby
# app/controllers/webhooks/shopify/orders_controller.rb
class Webhooks::Shopify::OrdersController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_shopify_webhook
  
  def create
    order_data = JSON.parse(request.body.read)
    
    # Find advertiser by shop domain
    shop_domain = request.headers['X-Shopify-Shop-Domain']
    shopify_store = ShopifyStore.find_by(shop_domain: shop_domain)
    
    unless shopify_store
      Rails.logger.warn "[Webhook] Unknown shop domain: #{shop_domain}"
      return head :not_found
    end
    
    # Create or update Order record
    order = shopify_store.advertiser.orders.find_or_create_by(external_id: order_data['id']) do |o|
      o.customer_id = order_data.dig('customer', 'id')
      o.email = order_data['email']
      o.total_price = order_data['total_price']
      o.order_number = order_data['order_number']
      o.created_at_shopify = order_data['created_at']
      o.discount_codes = order_data['discount_codes']&.pluck('code') || []
      o.line_items = order_data['line_items']
    end
    
    # Queue attribution job
    AttributeOrderToPostcardJob.perform_later(order.id)
    
    head :ok
  end
  
  private
  
  def verify_shopify_webhook
    data = request.body.read
    hmac = request.headers['X-Shopify-Hmac-Sha256']
    
    digest = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', ENV['SHOPIFY_WEBHOOK_SECRET'], data)
    )
    
    unless ActiveSupport::SecurityUtils.secure_compare(digest, hmac)
      Rails.logger.error "[Webhook] Invalid HMAC signature"
      head :unauthorized
    end
  end
end

# config/routes.rb
namespace :webhooks do
  namespace :shopify do
    post 'orders/create', to: 'orders#create'
  end
end
```

### Attribution Job

```ruby
# app/jobs/attribute_order_to_postcard_job.rb
class AttributeOrderToPostcardJob < ApplicationJob
  queue_as :default
  
  def perform(order_id)
    order = Order.find(order_id)
    advertiser = order.advertiser
    
    Rails.logger.info "[Attribution] Processing Order #{order.order_number}"
    
    # Method 1: Direct promo code match (STRONGEST SIGNAL)
    order.discount_codes.each do |code|
      contact = advertiser.campaign_contacts.find_by(unique_promo_code: code)
      if contact
        contact.track_conversion(order)
        Rails.logger.info "[Attribution] ✅ Promo code match: #{code}"
        return # Stop after first match
      end
    end
    
    Rails.logger.info "[Attribution] No promo code match for Order #{order.order_number}"
    
    # Additional methods will be added in Tier 2 & 3
    # - QR scan attribution
    # - Delivery window attribution
    # - Identity resolution
    
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "[Attribution] Order not found: #{order_id}"
  rescue => e
    Rails.logger.error "[Attribution] Error processing Order #{order_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Re-raise so job can be retried
  end
end
```

### Shopify Setup Instructions

**For customers to enable webhooks**:

1. Go to Shopify Admin → Settings → Notifications → Webhooks
2. Click "Create webhook"
3. Select event: **Order creation**
4. Format: JSON
5. URL: `https://app.nurture.com/webhooks/shopify/orders/create`
6. Webhook API version: `2024-10`

**Or via Shopify API** (automatic setup during OAuth):
```ruby
# app/services/shopify_client.rb
def setup_webhooks
  client = ShopifyAPI::Clients::Rest::Admin.new(session: @session)
  
  client.post(
    path: 'webhooks',
    body: {
      webhook: {
        topic: 'orders/create',
        address: "#{ENV['APP_URL']}/webhooks/shopify/orders/create",
        format: 'json'
      }
    }
  )
end
```

---

## Tier 2: QR Code Tracking

### Overview

**Priority**: 🟡 **BUILD SECOND** (Week 2)  
**Time Estimate**: 10-14 hours  
**Value**: Engagement metrics + backup attribution

**What it tracks**:
- QR code scans (engagement)
- Time from delivery to scan
- Scan → purchase correlation
- Multi-touch attribution
- Device/location data (optional)

**How it works**:
```
1. Generate unique tracking URL per postcard (e.g., nurture.app/r/abc123xyz)
2. Encode URL as QR code on postcard
3. Customer scans QR → redirects to Shopify with UTM params
4. Track scan event + set cookie for identity resolution
5. If customer purchases, attribute via cookie or time window
```

### Database Schema

```ruby
# db/migrate/xxx_add_qr_tracking_to_campaign_contacts.rb
class AddQrTrackingToCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    # QR code tracking
    add_column :campaign_contacts, :tracking_token, :string
    add_column :campaign_contacts, :tracking_url, :string
    add_column :campaign_contacts, :qr_scan_count, :integer, default: 0
    add_column :campaign_contacts, :first_scanned_at, :datetime
    add_column :campaign_contacts, :last_scanned_at, :datetime
    add_column :campaign_contacts, :scan_events, :jsonb, default: []
    
    add_index :campaign_contacts, :tracking_token, unique: true
    add_index :campaign_contacts, [:campaign_id, :qr_scan_count]
  end
end

# db/migrate/xxx_add_destination_url_to_campaigns.rb
class AddDestinationUrlToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :destination_url, :string
    add_column :campaigns, :total_qr_scans, :integer, default: 0
  end
end
```

### Model Implementation

```ruby
# app/models/campaign_contact.rb
class CampaignContact < ApplicationRecord
  before_create :generate_tracking_url
  
  # Track QR code scan
  def track_qr_scan(request_info = {})
    increment!(:qr_scan_count)
    self.first_scanned_at ||= Time.current
    self.last_scanned_at = Time.current
    
    # Store scan event details
    self.scan_events << {
      scanned_at: Time.current,
      ip: request_info[:ip],
      user_agent: request_info[:user_agent],
      referer: request_info[:referer]
    }
    
    save!
    
    # Update campaign-level stats
    campaign.increment!(:total_qr_scans)
    
    Rails.logger.info "[QR Scan] Campaign #{campaign.id}, Contact #{id}"
  end
  
  # Generate QR code as PNG data URL
  def qr_code_data_url
    require 'rqrcode'
    qr = RQRCode::QRCode.new(tracking_url)
    qr.as_png(
      size: 300,
      border_modules: 2,
      fill: 'black',
      color: 'white'
    ).to_data_url
  end
  
  # Generate QR code as SVG
  def qr_code_svg
    require 'rqrcode'
    qr = RQRCode::QRCode.new(tracking_url)
    qr.as_svg(
      module_size: 6,
      standalone: true
    )
  end
  
  # Days from delivery to first scan
  def time_to_scan
    return nil unless first_scanned_at && delivered_at
    (first_scanned_at - delivered_at) / 1.day
  end
  
  # Scan rate (did they scan?)
  def scanned?
    qr_scan_count > 0
  end
  
  private
  
  def generate_tracking_url
    self.tracking_token = SecureRandom.urlsafe_base64(16)
    self.tracking_url = Rails.application.routes.url_helpers.track_postcard_url(
      token: tracking_token,
      host: ENV['APP_URL'] || 'https://app.nurture.com'
    )
  end
end
```

### QR Redirect Controller

```ruby
# app/controllers/track_controller.rb
class TrackController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  
  # GET /r/:token
  def postcard
    contact = CampaignContact.find_by!(tracking_token: params[:token])
    
    # Track the scan
    contact.track_qr_scan({
      ip: request.remote_ip,
      user_agent: request.user_agent,
      referer: request.referer
    })
    
    # Set cookie for identity resolution (Tier 3)
    cookies.encrypted[:postcard_token] = {
      value: contact.tracking_token,
      expires: 30.days.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
    
    # Build destination URL with UTM tracking
    destination = contact.campaign.destination_url || 
                  contact.campaign.advertiser.website_url
    
    utm_params = {
      utm_source: 'postcard',
      utm_medium: 'direct_mail',
      utm_campaign: contact.campaign.slug || contact.campaign.id,
      utm_id: contact.tracking_token,
      utm_content: contact.campaign.creative&.id
    }
    
    redirect_url = URI.parse(destination)
    existing_query = redirect_url.query ? CGI.parse(redirect_url.query) : {}
    redirect_url.query = existing_query.merge(utm_params).to_query
    
    redirect_to redirect_url.to_s, allow_other_host: true
    
  rescue ActiveRecord::RecordNotFound
    # Invalid or expired token
    redirect_to ENV['APP_URL'] || 'https://nurture.com', alert: 'Invalid tracking link'
  end
end

# config/routes.rb
get '/r/:token', to: 'track#postcard', as: :track_postcard
```

### Update Attribution Job (Add QR Method)

```ruby
# app/jobs/attribute_order_to_postcard_job.rb
def perform(order_id)
  order = Order.find(order_id)
  advertiser = order.advertiser
  
  Rails.logger.info "[Attribution] Processing Order #{order.order_number}"
  
  # Method 1: Direct promo code match (STRONGEST SIGNAL)
  order.discount_codes.each do |code|
    contact = advertiser.campaign_contacts.find_by(unique_promo_code: code)
    if contact
      contact.track_conversion(order)
      Rails.logger.info "[Attribution] ✅ Promo code match: #{code}"
      return
    end
  end
  
  # Method 2: QR scan attribution (STRONG SIGNAL)
  if order.customer_id
    # Find postcards scanned by this customer in last 30 days
    recent_scans = advertiser.campaign_contacts
      .joins(:contact)
      .where(contacts: { external_id: order.customer_id })
      .where('last_scanned_at > ? AND last_scanned_at < ?', 30.days.ago, order.created_at_shopify)
      .order(last_scanned_at: :desc)
    
    if recent_scans.any?
      # Last-touch attribution to most recent scan
      recent_scans.first.track_conversion(order)
      Rails.logger.info "[Attribution] ✅ QR scan match (last-touch)"
      return
    end
  end
  
  # Method 3: Delivery window attribution (WEAK SIGNAL)
  if order.customer_id
    # Find postcards delivered to this customer in last 30 days
    recent_deliveries = advertiser.campaign_contacts
      .joins(:contact)
      .where(contacts: { external_id: order.customer_id })
      .where(status: :delivered)
      .where('delivered_at > ? AND delivered_at < ?', 30.days.ago, order.created_at_shopify)
      .order(delivered_at: :desc)
    
    if recent_deliveries.any?
      # Weak attribution: assume postcard influenced purchase
      recent_deliveries.first.track_conversion(order)
      Rails.logger.info "[Attribution] ⚠️ Delivery window match (weak attribution)"
      return
    end
  end
  
  Rails.logger.info "[Attribution] ❌ No attribution match for Order #{order.order_number}"
end
```

### Update Campaign Analytics

```ruby
# app/models/campaign.rb
def engagement_stats
  {
    total_scans: campaign_contacts.sum(:qr_scan_count),
    scan_rate: (campaign_contacts.where('qr_scan_count > 0').count.to_f / recipient_count * 100).round(2),
    avg_scans_per_recipient: (campaign_contacts.sum(:qr_scan_count).to_f / recipient_count).round(2),
    avg_time_to_scan: campaign_contacts.where.not(first_scanned_at: nil)
                                       .average('EXTRACT(EPOCH FROM (first_scanned_at - delivered_at)) / 86400')
                                       &.round(1) || 0,
    scan_to_conversion_rate: total_qr_scans > 0 ? 
      (conversion_count.to_f / campaign_contacts.where('qr_scan_count > 0').count * 100).round(2) : 0
  }
end
```

### Include QR Code in Postcard Template

```erb
<!-- app/views/postcard_templates/_default_back.html.erb -->
<div class="postcard-back">
  <div class="qr-section">
    <%= image_tag @qr_code_data_url, class: 'qr-code', alt: 'Scan to shop' %>
    <p class="qr-instruction">Scan for 15% off</p>
  </div>
  
  <div class="promo-section">
    <p class="promo-text">Or use code:</p>
    <p class="promo-code"><%= @promo_code %></p>
    <p class="expiry">Expires <%= @campaign.expires_at.strftime('%m/%d/%Y') %></p>
  </div>
</div>
```

**Pass data to Lob**:
```ruby
# app/services/lob_client.rb
def self.create_postcard(campaign_contact:, campaign:, from_address:)
  # Merge QR code and promo code into template data
  contact_data = {
    first_name: campaign_contact.first_name,
    # ... other contact data
    qr_code_data_url: campaign_contact.qr_code_data_url,
    promo_code: campaign_contact.unique_promo_code,
    tracking_url: campaign_contact.tracking_url
  }
  
  front_content = campaign.render_front_html(contact_data)
  back_content = campaign.render_back_html(contact_data)
  
  # ... rest of Lob API call
end
```

---

## Tier 3: Identity Resolution

### Overview

**Priority**: 🟢 **BUILD LATER** (Month 2)  
**Time Estimate**: 30-40 hours  
**Value**: Full funnel visibility, cross-device tracking

**What it tracks**:
- Anonymous visitor sessions
- Page views and behavior
- Anonymous → known customer matching
- Multi-session journeys
- Cross-device conversions
- Full attribution path

**How it works**:
```
1. Customer installs tracking pixel on Shopify store
2. Anonymous visitor browses website → generate visitor_id
3. Visitor adds to cart (still anonymous)
4. Visitor checks out → reveal customer_id/email
5. MATCH: visitor_id → customer_id → contact → postcard
6. Attribute conversion even without promo code or QR scan
```

### Database Schema

```ruby
# db/migrate/xxx_create_visitor_sessions.rb
class CreateVisitorSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :visitor_sessions do |t|
      t.references :advertiser, null: false, foreign_key: true
      t.references :contact, null: true, foreign_key: true
      t.references :campaign_contact, null: true, foreign_key: true
      
      # Visitor tracking
      t.string :visitor_id, null: false  # Anonymous ID from browser
      t.string :session_id
      t.string :ip_address
      t.string :user_agent
      
      # Attribution data
      t.jsonb :utm_params, default: {}
      t.jsonb :device_info, default: {}
      
      # Identity resolution
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.datetime :identified_at  # When matched to known customer
      
      t.timestamps
    end
    
    add_index :visitor_sessions, :visitor_id
    add_index :visitor_sessions, [:advertiser_id, :visitor_id]
    add_index :visitor_sessions, :identified_at
    add_index :visitor_sessions, [:contact_id, :campaign_contact_id]
  end
end

# db/migrate/xxx_create_page_views.rb
class CreatePageViews < ActiveRecord::Migration[8.0]
  def change
    create_table :page_views do |t|
      t.references :visitor_session, null: false, foreign_key: true
      t.references :advertiser, null: false, foreign_key: true
      
      t.string :url
      t.string :path
      t.string :referer
      t.string :page_title
      t.jsonb :utm_params, default: {}
      
      t.datetime :viewed_at
      t.timestamps
    end
    
    add_index :page_views, [:advertiser_id, :viewed_at]
    add_index :page_views, :url
    add_index :page_views, :path
  end
end

# db/migrate/xxx_add_tracking_token_to_advertisers.rb
class AddTrackingTokenToAdvertisers < ActiveRecord::Migration[8.0]
  def change
    add_column :advertisers, :tracking_token, :string
    add_column :advertisers, :tracking_enabled, :boolean, default: false
    
    add_index :advertisers, :tracking_token, unique: true
  end
end

# app/models/advertiser.rb
before_create :generate_tracking_token

def generate_tracking_token
  self.tracking_token = SecureRandom.urlsafe_base64(24)
end
```

### Models

```ruby
# app/models/visitor_session.rb
class VisitorSession < ApplicationRecord
  belongs_to :advertiser
  belongs_to :contact, optional: true
  belongs_to :campaign_contact, optional: true
  has_many :page_views, dependent: :destroy
  
  # Identify anonymous visitor as known customer
  def identify!(customer_id, email)
    contact = advertiser.contacts.find_by(external_id: customer_id) ||
              advertiser.contacts.find_by(email: email)
    
    if contact
      update!(
        contact: contact,
        identified_at: Time.current
      )
      
      # If visitor came from a postcard QR scan, link to that campaign
      if campaign_contact.present?
        Rails.logger.info "[Identity] Resolved visitor #{visitor_id} → Contact #{contact.id} → Campaign #{campaign_contact.campaign_id}"
      end
    end
  end
  
  # Customer journey summary
  def journey
    page_views.order(viewed_at: :asc).pluck(:path, :viewed_at)
  end
  
  # Time on site
  def session_duration
    return 0 unless first_seen_at && last_seen_at
    ((last_seen_at - first_seen_at) / 60).round(1) # minutes
  end
end

# app/models/page_view.rb
class PageView < ApplicationRecord
  belongs_to :visitor_session
  belongs_to :advertiser
  
  validates :url, presence: true
  validates :viewed_at, presence: true
end
```

### JavaScript Tracking Pixel

**Customer installs this on their Shopify store**:

```html
<!-- Nurture Tracking Pixel -->
<!-- Add to theme.liquid before </head> -->
<script>
(function() {
  // Configuration
  var nurtureConfig = {
    advertiserToken: '{{ shop.metafields.nurture.tracking_token }}', // Set via admin
    apiUrl: 'https://app.nurture.com'
  };
  
  // Generate or retrieve visitor ID
  var visitorId = localStorage.getItem('nurture_visitor_id');
  if (!visitorId) {
    visitorId = 'v_' + Math.random().toString(36).substr(2, 16) + Date.now();
    localStorage.setItem('nurture_visitor_id', visitorId);
  }
  
  // Check if they came from a postcard QR code
  var postcardToken = null;
  var cookies = document.cookie.split(';');
  for (var i = 0; i < cookies.length; i++) {
    var cookie = cookies[i].trim();
    if (cookie.startsWith('postcard_token=')) {
      postcardToken = cookie.substring('postcard_token='.length);
    }
  }
  
  // Track page view
  function trackPageView() {
    var params = new URLSearchParams(window.location.search);
    
    fetch(nurtureConfig.apiUrl + '/api/track/pageview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        visitor_id: visitorId,
        url: window.location.href,
        path: window.location.pathname,
        referer: document.referrer,
        page_title: document.title,
        utm_source: params.get('utm_source'),
        utm_medium: params.get('utm_medium'),
        utm_campaign: params.get('utm_campaign'),
        utm_id: params.get('utm_id'),
        utm_content: params.get('utm_content'),
        postcard_token: postcardToken,
        advertiser_token: nurtureConfig.advertiserToken
      })
    }).catch(function(err) {
      console.error('[Nurture] Tracking error:', err);
    });
  }
  
  // Track identity on checkout
  function trackIdentity() {
    // Shopify checkout page exposes customer info
    if (window.Shopify && window.Shopify.checkout) {
      var checkout = window.Shopify.checkout;
      
      fetch(nurtureConfig.apiUrl + '/api/track/identify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          visitor_id: visitorId,
          customer_id: checkout.customer_id,
          email: checkout.email,
          order_id: checkout.order_id,
          advertiser_token: nurtureConfig.advertiserToken
        })
      }).catch(function(err) {
        console.error('[Nurture] Identity error:', err);
      });
    }
  }
  
  // Run tracking
  if (nurtureConfig.advertiserToken) {
    trackPageView();
    
    // Track identity on checkout completion
    if (window.location.pathname.includes('/checkouts/') || 
        window.location.pathname.includes('/orders/')) {
      trackIdentity();
    }
  }
})();
</script>
```

### API Controller

```ruby
# app/controllers/api/track_controller.rb
class Api::TrackController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :verify_advertiser_token
  before_action :rate_limit_tracking
  
  # POST /api/track/pageview
  def pageview
    session = VisitorSession.find_or_initialize_by(
      advertiser: @advertiser,
      visitor_id: params[:visitor_id]
    )
    
    # Update session metadata
    session.last_seen_at = Time.current
    session.first_seen_at ||= Time.current
    session.ip_address ||= request.remote_ip
    session.user_agent ||= request.user_agent
    session.utm_params = params.slice(:utm_source, :utm_medium, :utm_campaign, :utm_id, :utm_content).compact
    
    # If they came from QR code, link to campaign contact
    if params[:postcard_token].present?
      contact = @advertiser.campaign_contacts.find_by(tracking_token: params[:postcard_token])
      session.campaign_contact = contact if contact
    end
    
    session.save!
    
    # Record page view
    session.page_views.create!(
      advertiser: @advertiser,
      url: params[:url],
      path: params[:path],
      referer: params[:referer],
      page_title: params[:page_title],
      utm_params: session.utm_params,
      viewed_at: Time.current
    )
    
    head :ok
    
  rescue => e
    Rails.logger.error "[Tracking] Pageview error: #{e.message}"
    head :ok # Always return 200 to not break customer's site
  end
  
  # POST /api/track/identify
  def identify
    session = VisitorSession.find_by(
      advertiser: @advertiser,
      visitor_id: params[:visitor_id]
    )
    
    return head :not_found unless session
    
    # IDENTITY RESOLUTION: Match anonymous visitor to known customer
    session.identify!(params[:customer_id], params[:email])
    
    # If session is linked to a campaign contact AND order exists, track conversion
    if session.campaign_contact && params[:order_id]
      order = @advertiser.orders.find_by(external_id: params[:order_id])
      
      if order && !session.campaign_contact.attributed_order_ids.include?(order.id)
        session.campaign_contact.track_conversion(order)
        Rails.logger.info "[Attribution] ✅ Identity resolution: Order #{order.order_number} → Campaign #{session.campaign_contact.campaign_id}"
      end
    end
    
    head :ok
    
  rescue => e
    Rails.logger.error "[Tracking] Identity error: #{e.message}"
    head :ok
  end
  
  private
  
  def verify_advertiser_token
    @advertiser = Advertiser.find_by!(
      tracking_token: params[:advertiser_token],
      tracking_enabled: true
    )
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "[Tracking] Invalid advertiser token: #{params[:advertiser_token]}"
    head :unauthorized
  end
  
  def rate_limit_tracking
    # Prevent abuse: max 100 requests per visitor per minute
    cache_key = "tracking:#{params[:visitor_id]}"
    count = Rails.cache.read(cache_key) || 0
    
    if count > 100
      Rails.logger.warn "[Tracking] Rate limit exceeded: #{params[:visitor_id]}"
      head :too_many_requests
    else
      Rails.cache.write(cache_key, count + 1, expires_in: 1.minute)
    end
  end
end

# config/routes.rb
namespace :api do
  namespace :track do
    post 'pageview', to: 'track#pageview'
    post 'identify', to: 'track#identify'
  end
end
```

### Update Attribution Job (Add Identity Resolution)

```ruby
# app/jobs/attribute_order_to_postcard_job.rb
def perform(order_id)
  order = Order.find(order_id)
  advertiser = order.advertiser
  
  # Method 1: Direct promo code match
  # ... (from Tier 1)
  
  # Method 2: QR scan attribution
  # ... (from Tier 2)
  
  # Method 3: Delivery window attribution
  # ... (from Tier 2)
  
  # Method 4: Identity resolution (NEW - TIER 3)
  if order.customer_id || order.email
    # Find visitor sessions that were identified as this customer
    identified_sessions = advertiser.visitor_sessions
      .where.not(campaign_contact_id: nil)  # Must be linked to a postcard
      .where(contact_id: order.contact&.id)
      .or(advertiser.visitor_sessions.where(
        "utm_params->>'utm_id' IS NOT NULL"  # Or came from UTM with postcard token
      ))
      .where('identified_at > ? AND identified_at < ?', 30.days.ago, order.created_at_shopify)
      .order(identified_at: :desc)
    
    if identified_sessions.any?
      session = identified_sessions.first
      session.campaign_contact.track_conversion(order)
      Rails.logger.info "[Attribution] ✅ Identity resolution match"
      return
    end
  end
  
  Rails.logger.info "[Attribution] ❌ No attribution match for Order #{order.order_number}"
end
```

---

## Analytics Dashboard

### Overview

Customers need a visual dashboard to understand campaign performance. Without analytics, attribution data is useless.

**Key metrics to display**:
1. **Delivery metrics**: Sent, delivered, failed
2. **Engagement metrics**: QR scans, scan rate, time to scan
3. **Conversion metrics**: Orders, revenue, ROAS
4. **Segment performance**: Which audiences convert best
5. **Creative performance**: Which designs work best (A/B testing)

### Campaign Show Page Analytics

```erb
<!-- app/views/campaigns/show.html.erb -->
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <div class="flex items-center justify-between mb-8">
    <h1 class="text-3xl font-bold text-gray-900"><%= @campaign.name %></h1>
    <span class="px-3 py-1 text-sm font-semibold rounded-full <%= status_badge_class(@campaign.status) %>">
      <%= @campaign.status.humanize %>
    </span>
  </div>
  
  <!-- Performance Summary -->
  <% if @campaign.successfully_sent? %>
    <% stats = @campaign.attribution_stats %>
    <% engagement = @campaign.engagement_stats %>
    
    <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
      <!-- Delivery -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Delivered</dt>
                <dd class="text-lg font-medium text-gray-900"><%= @campaign.delivered_count %> / <%= @campaign.recipient_count %></dd>
                <dd class="text-xs text-gray-500"><%= ((@campaign.delivered_count.to_f / @campaign.recipient_count) * 100).round(1) %>% delivery rate</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Engagement -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z"/>
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">QR Scans</dt>
                <dd class="text-lg font-medium text-gray-900"><%= engagement[:total_scans] %></dd>
                <dd class="text-xs text-gray-500"><%= engagement[:scan_rate] %>% scan rate</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Conversions -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Conversions</dt>
                <dd class="text-lg font-medium text-gray-900"><%= stats[:total_conversions] %></dd>
                <dd class="text-xs text-gray-500"><%= stats[:conversion_rate] %>% conversion rate</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      
      <!-- ROAS -->
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <svg class="h-6 w-6 text-yellow-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">ROAS</dt>
                <dd class="text-lg font-medium text-gray-900"><%= stats[:roas] %>x</dd>
                <dd class="text-xs text-gray-500">$<%= number_with_precision(stats[:total_revenue], precision: 2) %> revenue</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Detailed Metrics -->
    <div class="bg-white shadow rounded-lg p-6 mb-8">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Performance Details</h3>
      <dl class="grid grid-cols-1 gap-5 sm:grid-cols-3">
        <div class="px-4 py-5 bg-gray-50 rounded-lg">
          <dt class="text-sm font-medium text-gray-500">Cost Per Acquisition</dt>
          <dd class="mt-1 text-2xl font-semibold text-gray-900">$<%= number_with_precision(stats[:cost_per_acquisition], precision: 2) %></dd>
        </div>
        <div class="px-4 py-5 bg-gray-50 rounded-lg">
          <dt class="text-sm font-medium text-gray-500">Average Order Value</dt>
          <dd class="mt-1 text-2xl font-semibold text-gray-900">$<%= number_with_precision(stats[:avg_order_value], precision: 2) %></dd>
        </div>
        <div class="px-4 py-5 bg-gray-50 rounded-lg">
          <dt class="text-sm font-medium text-gray-500">Avg Time to Conversion</dt>
          <dd class="mt-1 text-2xl font-semibold text-gray-900"><%= stats[:avg_time_to_conversion] %> days</dd>
        </div>
      </dl>
    </div>
    
    <!-- Segment Performance -->
    <% segment_perf = @campaign.segment_performance %>
    <% if segment_perf.any? %>
      <div class="bg-white shadow rounded-lg p-6 mb-8">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Segment Performance</h3>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Segment</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Sent</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Conversions</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Conv. Rate</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Revenue</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Avg Order</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <% segment_perf.each do |segment| %>
                <tr>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= segment.rfm_segment %></td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500"><%= segment.sent_count %></td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500"><%= segment.conversions %></td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500"><%= ((segment.conversions.to_f / segment.sent_count) * 100).round(1) %>%</td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">$<%= number_with_precision(segment.revenue, precision: 2) %></td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">$<%= number_with_precision(segment.avg_order_value, precision: 2) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>
  <% end %>
  
  <!-- Recipients List -->
  <div class="bg-white shadow rounded-lg p-6">
    <h3 class="text-lg font-medium text-gray-900 mb-4">Recipients (<%= @campaign.recipient_count %>)</h3>
    <!-- Existing recipients table -->
  </div>
</div>
```

---

## Dry Run Mode (Testing)

### Overview

**Priority**: 🟢 **BUILD WITH TIER 1** (Week 1)  
**Time Estimate**: 2-3 hours  
**Value**: Safe testing without Lob API costs

Dry run mode simulates the entire campaign send process without calling Lob API or charging money. Critical for:
- Development/testing
- Demos to customers
- QA before production sends

### Implementation

```ruby
# db/migrate/xxx_add_dry_run_to_campaigns.rb
class AddDryRunToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :dry_run, :boolean, default: false
  end
end
```

```ruby
# app/models/campaign.rb
def send_now!(dry_run: false)
  raise "Campaign not ready to send" unless sendable?
  
  self.dry_run = dry_run
  update!(status: :processing, sent_at: Time.current)
  
  if dry_run
    # Instant processing for dry runs
    SendCampaignJob.set(wait: 2.seconds).perform_later(id)
  else
    SendCampaignJob.perform_later(id)
  end
end

def dry_run?
  dry_run == true
end
```

```ruby
# app/jobs/send_campaign_job.rb
class SendCampaignJob < ApplicationJob
  queue_as :default
  
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    
    if campaign.dry_run?
      simulate_campaign_send(campaign)
    else
      send_campaign_via_lob(campaign)
    end
  end
  
  private
  
  def simulate_campaign_send(campaign)
    Rails.logger.info "[DRY RUN] Simulating send for Campaign #{campaign.id}: #{campaign.name}"
    
    campaign.campaign_contacts.find_each do |contact|
      # Generate fake postcard ID
      fake_postcard_id = "psc_dryrun_#{SecureRandom.hex(8)}"
      
      # Simulate 90% success rate, 10% failures
      if rand < 0.9
        contact.update!(
          lob_postcard_id: fake_postcard_id,
          status: :sent,
          sent_at: Time.current,
          delivered_at: 3.days.from_now,  # Simulate delivery
          estimated_delivery_date: 5.days.from_now.to_date
        )
        campaign.increment!(:sent_count)
      else
        # Simulate various failure scenarios
        error_messages = [
          "Invalid address format",
          "Address verification failed",
          "Insufficient postage",
          "Invalid ZIP code"
        ]
        
        contact.update!(
          status: :failed,
          error_message: "[DRY RUN] #{error_messages.sample}"
        )
        campaign.increment!(:failed_count)
      end
      
      # Simulate processing time (0.01s per postcard)
      sleep 0.01
    end
    
    # Mark campaign as complete
    if campaign.failed_count == 0
      campaign.update!(status: :completed)
    elsif campaign.failed_count < campaign.recipient_count
      campaign.update!(status: :completed_with_errors)
    else
      campaign.update!(status: :failed)
    end
    
    Rails.logger.info "[DRY RUN] Completed: #{campaign.sent_count} sent, #{campaign.failed_count} failed (Cost: $0.00)"
  end
  
  def send_campaign_via_lob(campaign)
    # ... existing real Lob sending code
  end
end
```

### UI Implementation

```erb
<!-- app/views/campaigns/tabs/_review.html.erb -->
<div class="bg-white shadow sm:rounded-lg p-6">
  <h2 class="text-lg font-medium text-gray-900 mb-4">Review & Send</h2>
  
  <!-- Cost Summary -->
  <div class="bg-gray-50 p-4 rounded-lg mb-6">
    <dl class="grid grid-cols-1 gap-4 sm:grid-cols-3">
      <div>
        <dt class="text-sm font-medium text-gray-500">Recipients</dt>
        <dd class="text-2xl font-semibold text-gray-900"><%= @campaign.recipient_count %></dd>
      </div>
      <div>
        <dt class="text-sm font-medium text-gray-500">Estimated Cost</dt>
        <dd class="text-2xl font-semibold text-gray-900">$<%= number_with_precision(@campaign.estimated_cost_dollars, precision: 2) %></dd>
      </div>
      <div>
        <dt class="text-sm font-medium text-gray-500">Cost per Postcard</dt>
        <dd class="text-2xl font-semibold text-gray-900">$1.05</dd>
      </div>
    </dl>
  </div>
  
  <!-- Send Buttons -->
  <div class="flex flex-col sm:flex-row gap-3">
    <!-- Dry Run (Test) -->
    <%= button_to "Test Send (Free)",
        send_now_campaign_path(@advertiser.slug, @campaign, dry_run: true),
        method: :post,
        class: "inline-flex items-center justify-center px-6 py-3 border border-gray-300 shadow-sm text-base font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50",
        data: { confirm: "This will simulate sending #{@campaign.recipient_count} postcards without calling Lob API or charging your account. Continue?" } do %>
      <svg class="-ml-1 mr-2 h-5 w-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
      </svg>
      Test Send (Free)
    <% end %>
    
    <!-- Real Send -->
    <%= button_to "Send Campaign ($#{number_with_precision(@campaign.estimated_cost_dollars, precision: 2)})",
        send_now_campaign_path(@advertiser.slug, @campaign),
        method: :post,
        class: "inline-flex items-center justify-center px-6 py-3 border border-transparent shadow-sm text-base font-medium rounded-md text-white bg-gray-900 hover:bg-gray-800",
        data: { confirm: "⚠️ This will send #{@campaign.recipient_count} REAL postcards via Lob and charge $#{number_with_precision(@campaign.estimated_cost_dollars, precision: 2)} to your account. This cannot be undone. Continue?" } do %>
      <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
      </svg>
      Send Campaign
    <% end %>
  </div>
  
  <!-- Help Text -->
  <div class="mt-4 text-sm text-gray-500">
    <p><strong>Test Send</strong>: Simulates the entire send process without calling Lob API or charging money. Perfect for testing your campaign setup.</p>
    <p class="mt-2"><strong>Send Campaign</strong>: Sends real postcards via Lob. You will be charged immediately.</p>
  </div>
</div>
```

```ruby
# app/controllers/campaigns_controller.rb
def send_now
  unless @campaign.sendable?
    redirect_to edit_campaign_path(@advertiser.slug, @campaign),
                alert: 'Campaign not ready to send. Add recipients and select a template.'
    return
  end
  
  # Calculate final cost
  @campaign.calculate_estimated_cost!
  
  # Check for dry run parameter
  dry_run = params[:dry_run] == 'true'
  
  @campaign.send_now!(dry_run: dry_run)
  
  message = if dry_run
    "Test send started. Check back in a few seconds to see simulated results."
  else
    "Campaign is being sent. You will receive an email when complete."
  end
  
  redirect_to campaign_path(@advertiser.slug, @campaign), notice: message
end
```

### Development Environment Setup

```ruby
# config/initializers/lob.rb
Lob.api_key = if Rails.env.production?
  ENV['LOB_LIVE_API_KEY']  # Real money
elsif Rails.env.test?
  'test_fake_key_for_tests' # Test suite
else
  ENV['LOB_TEST_API_KEY']   # FREE test mode (requires real Lob account)
end

# Optional: Use mock service when offline
if Rails.env.development? && ENV['USE_LOB_MOCK'] == 'true'
  Rails.logger.info "[LOB] Using mock Lob service (offline mode)"
  # LobClient will return fake data
end
```

```bash
# .env
# Option 1: Use Lob test API (free, requires internet)
LOB_TEST_API_KEY=test_your_key_here

# Option 2: Use mock service (free, works offline)
USE_LOB_MOCK=true

# Production
LOB_LIVE_API_KEY=live_your_key_here
```

---

## Implementation Roadmap

### Phase 1: MVP Attribution (Week 1, 20-24 hours)

**Goal**: Launch beta with basic ROI tracking

**Build**:
1. ✅ Tier 1: Promo code attribution (12 hours)
   - Database migrations
   - Generate unique codes
   - Shopify webhook setup
   - Attribution job
2. ✅ Basic analytics dashboard (8 hours)
   - Campaign performance page
   - ROAS calculation
   - Segment performance
3. ✅ Dry run mode (3 hours)
   - Simulate sends
   - Test UI

**Result**: Customers can track conversions and prove ROI

---

### Phase 2: Enhanced Tracking (Week 2-3, 16-20 hours)

**Goal**: Add engagement metrics and backup attribution

**Build**:
1. ✅ Tier 2: QR code tracking (14 hours)
   - QR code generation
   - Redirect endpoint
   - Scan tracking
   - Cookie for identity resolution
2. ✅ Analytics enhancements (6 hours)
   - Engagement metrics
   - Time-based insights
   - Export reports

**Result**: Understand customer engagement beyond just conversions

---

### Phase 3: Advanced Attribution (Month 2, 40-50 hours)

**Goal**: Full-funnel tracking for competitive advantage

**Build**:
1. ✅ Tier 3: Identity resolution (40 hours)
   - Visitor session tracking
   - JavaScript pixel
   - API endpoints
   - Identity matching
2. ✅ Advanced analytics (10 hours)
   - Customer journey visualization
   - Multi-touch attribution
   - Cohort analysis

**Result**: Enterprise-level attribution rivaling major marketing platforms

---

## Success Metrics

### Attribution System Success Criteria

| Metric | Target | Notes |
|--------|--------|-------|
| **Attribution Rate** | >70% | % of orders attributed to postcards |
| **Promo Code Usage** | >40% | % of recipients using codes |
| **QR Scan Rate** | >15% | % of delivered postcards scanned |
| **ROAS Visibility** | 100% | All campaigns show ROAS |
| **Time to Attribution** | <24h | Orders attributed within 24 hours |

### Customer Value Metrics

| Metric | Target | Impact |
|--------|--------|--------|
| **Churn Reduction** | -50% | Customers with attribution churn less |
| **Campaign Frequency** | 2x | Customers send more campaigns when they see ROI |
| **Referrals** | +30% | Customers refer others when they prove ROI |
| **Pricing Power** | +40% | Can charge premium when providing attribution |

---

## Testing Strategy

### Unit Tests

```ruby
# test/models/campaign_contact_test.rb
class CampaignContactTest < ActiveSupport::TestCase
  test "generates unique promo code on creation" do
    contact = campaign_contacts(:one)
    assert_not_nil contact.unique_promo_code
    assert_match /\A[A-Z0-9]{8,12}\z/, contact.unique_promo_code
  end
  
  test "generates unique tracking URL on creation" do
    contact = campaign_contacts(:one)
    assert_not_nil contact.tracking_token
    assert_not_nil contact.tracking_url
    assert_match /\/r\/[A-Za-z0-9_-]+/, contact.tracking_url
  end
  
  test "tracks conversion correctly" do
    contact = campaign_contacts(:one)
    order = orders(:one)
    
    assert_difference 'contact.redemption_count', 1 do
      contact.track_conversion(order)
    end
    
    assert_equal order.total_price.to_f, contact.attributed_revenue
    assert_not_nil contact.first_conversion_at
    assert_includes contact.attributed_order_ids, order.id
  end
  
  test "does not track same order twice" do
    contact = campaign_contacts(:one)
    order = orders(:one)
    
    contact.track_conversion(order)
    
    assert_no_difference 'contact.redemption_count' do
      contact.track_conversion(order)
    end
  end
end
```

### Integration Tests

```ruby
# test/integration/attribution_flow_test.rb
class AttributionFlowTest < ActionDispatch::IntegrationTest
  test "promo code attribution flow" do
    # 1. Send campaign
    campaign = campaigns(:one)
    contact = campaign.campaign_contacts.first
    
    post send_now_campaign_path(campaign.advertiser.slug, campaign, dry_run: true)
    perform_enqueued_jobs
    
    contact.reload
    assert_equal 'sent', contact.status
    assert_not_nil contact.unique_promo_code
    
    # 2. Create Shopify order with promo code
    order = campaign.advertiser.orders.create!(
      external_id: '12345',
      customer_id: contact.contact.external_id,
      email: contact.email,
      total_price: 125.00,
      order_number: 'ORDER-123',
      discount_codes: [contact.unique_promo_code]
    )
    
    # 3. Trigger attribution job
    AttributeOrderToPostcardJob.perform_now(order.id)
    
    # 4. Verify attribution
    contact.reload
    assert_equal 1, contact.redemption_count
    assert_equal 125.00, contact.attributed_revenue
    assert_includes contact.attributed_order_ids, order.id
    
    # 5. Verify campaign stats updated
    campaign.reload
    assert_equal 1, campaign.conversion_count
    assert campaign.attributed_revenue > 0
  end
end
```

---

## Open Questions & Future Enhancements

### Questions to Resolve

1. **Multi-touch attribution**: Should we split credit across multiple postcards?
   - Last-touch (current): 100% credit to most recent postcard
   - First-touch: 100% credit to first postcard
   - Linear: Split credit evenly
   - Time-decay: More credit to recent interactions

2. **Attribution window**: How long after delivery do we attribute?
   - Current: 30 days
   - Considerations: Product type (impulse vs. considered purchase)

3. **Offline conversions**: How to track in-store purchases?
   - Options: POS integration, manual upload, phone call tracking

4. **Promo code conflicts**: What if customer uses multiple codes?
   - Current: First match wins
   - Alternative: Postcard code takes priority

### Future Enhancements

1. **A/B testing built-in**
   - Split campaigns automatically
   - Statistical significance calculation
   - Winner declaration

2. **Predictive analytics**
   - ML model to predict conversion likelihood
   - Optimal send timing
   - Personalized offers

3. **Customer journey visualization**
   - Sankey diagram showing paths
   - Touchpoint analysis
   - Drop-off identification

4. **Cohort analysis**
   - Retention curves
   - Lifetime value prediction
   - Segment evolution over time

5. **Integration with other channels**
   - Email + postcard combined attribution
   - Social media + postcard
   - Omnichannel customer view

---

## Related Documentation

- [Code Quality Assessment](./CODE-QUALITY-ASSESSMENT.md)
- [Shopify Integration Requirements](./nurture-shopify-integration-requirements.md)
- [Lob Postcard Integration MVP](./lob-postcard-integration-mvp.md)
- [Campaign Status Flow](./campaign-status-flow.md)

---

**Last Updated**: October 7, 2025  
**Status**: Specification complete, implementation pending  
**Next Steps**: Build Tier 1 (promo code attribution) + dry run mode in Week 1

