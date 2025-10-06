# Shopify Integration - Data Model Architecture

## Overview
This shows how the new Shopify models integrate with your existing application.

---

## 📊 COMPLETE DATA MODEL

```
┌─────────────────────────────────────────────────────────────────┐
│                         ADVERTISER                               │
│  (existing - your tenant/brand entity)                          │
│  - name, slug, address, settings                                │
└────┬──────────────────────────────┬───────────────────┬─────────┘
     │                              │                   │
     │                              │                   │
     │                              │                   │
┌────▼────────────┐         ┌──────▼──────┐      ┌────▼────────┐
│  ShopifyStore   │         │  Campaign   │      │    User     │
│  (NEW)          │         │  (existing) │      │  (existing) │
│                 │         │             │      └─────────────┘
│  - shop_domain  │         │  - name     │
│  - access_token │         │  - status   │
│  - status       │         │  - template │
│  - sync_freq    │         └──────┬──────┘
└────┬────────────┘                │
     │                              │
     │ source (polymorphic)         │
     │                              │
┌────▼────────────┐         ┌──────▼──────────────┐
│    Contact      │◄────────│  CampaignContact    │
│    (NEW)        │         │  (EXISTING/ENHANCE) │
│                 │         │                     │
│  - email        │         │  - lob_postcard_id  │
│  - first_name   │         │  - status           │
│  - last_name    │         │  - tracking_number  │
│  - phone        │         │  - costs            │
│  - tags         │         │  - delivery_date    │
│  - total_spent  │         │  + contact_id (NEW) │
│  - addresses    │         └─────────────────────┘
└────┬────────────┘
     │
     │
┌────▼────────────┐         ┌─────────────────┐
│     Order       │         │     Product     │
│     (NEW)       │         │     (NEW)       │
│                 │         │                 │
│  - order_number │         │  - title        │
│  - total_price  │         │  - variants     │
│  - line_items   │         │  - images       │
│  - ordered_at   │         │  - tags         │
│  + contact_id   │         └─────────────────┘
└─────────────────┘                │
                                   │
                    Both have polymorphic source
                    (ShopifyStore, ManualUpload, etc.)

┌─────────────────────────────────────────────────────────────────┐
│                           SyncJob (NEW)                          │
│                                                                  │
│  Tracks every sync operation                                    │
│  - shopify_store_id                                             │
│  - status (pending/running/completed/failed)                    │
│  - records_processed (customers: 1234, orders: 5678)            │
│  - started_at, completed_at, duration                           │
│  - error_message                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 DATA FLOW: Shopify → Your App

### Initial Connection
```
1. User clicks "Connect Shopify"
   ↓
2. OAuth to Shopify (approve scopes)
   ↓
3. Create ShopifyStore record
   - Save encrypted access_token
   - Save shop metadata
   ↓
4. Trigger initial sync job
   ↓
5. ShopifyFullSyncJob runs:
   ├─ Fetch customers → Create Contacts
   ├─ Fetch orders → Create Orders (link to Contacts)
   └─ Fetch products → Create Products
   ↓
6. Update ShopifyStore:
   - initial_sync_completed = true
   - last_sync_at = now
   ↓
7. Send email: "Sync complete! 1,234 customers synced"
```

### Recurring Sync (every hour)
```
1. Recurring job fires (from config/recurring.yml)
   ↓
2. Find all ShopifyStores with:
   - status = 'connected'
   - sync_frequency = 'hourly'
   ↓
3. For each store, run ShopifyIncrementalSyncJob:
   ├─ Fetch customers updated since last_sync_at
   ├─ Fetch orders updated since last_sync_at
   └─ Fetch products updated since last_sync_at
   ↓
4. Upsert (update if exists, create if new)
   - Prevents duplicates
   - Updates changed data
   ↓
5. Update ShopifyStore.last_sync_at
```

---

## 🎯 KEY RELATIONSHIPS

### Contact ↔ CampaignContact (NEW)

**Before Shopify:**
```ruby
CampaignContact
  - first_name, last_name (duplicated per campaign)
  - address fields (duplicated per campaign)
  - email (duplicated per campaign)
```

**After Shopify:**
```ruby
Contact (source of truth)
  - first_name, last_name (stored once)
  - addresses (JSON array, primary + alternates)
  - email, phone
  - total_spent, orders_count
  
CampaignContact (campaign-specific send record)
  - contact_id → references Contact
  - first_name, last_name (copied from Contact, can override)
  - address_* (copied from Contact, can override)
  - lob_postcard_id (Lob tracking)
  - status (pending/sent/delivered/failed)
  - tracking_number, delivery_date
```

**Why both?**
- Contact = Customer in your database (permanent)
- CampaignContact = Specific mailing (per campaign)
- User might mail same Contact 10 times = 10 CampaignContacts
- Each CampaignContact can have different address if needed

---

### Polymorphic Source

All data records know where they came from:

```ruby
Contact
  - source_type: "ShopifyStore"
  - source_id: 123
  → belongs_to :source, polymorphic: true

Order
  - source_type: "ShopifyStore"
  - source_id: 123
  → belongs_to :source, polymorphic: true

Product
  - source_type: "ShopifyStore"
  - source_id: 123
  → belongs_to :source, polymorphic: true
```

**Benefits:**
- Same tables support multiple sources
- Can add "ManualUpload", "CsvImport", "BigCommerce" later
- Queries work across all sources or filtered by source
- Future-proof architecture

**Queries:**
```ruby
# All contacts from Shopify
Contact.where(source_type: "ShopifyStore")

# All contacts from specific store
Contact.where(source_type: "ShopifyStore", source_id: store.id)

# All contacts for advertiser (regardless of source)
advertiser.contacts
```

---

## 📋 CAMPAIGN WORKFLOW (Proposed)

### Old Way (CSV Upload)
```
1. User exports customer list from Shopify → CSV
2. User uploads CSV to your app
3. App parses CSV → creates CampaignContacts
4. User designs postcard
5. User sends campaign
```

### New Way (Integrated)
```
1. Shopify data already synced (Contacts exist in database)
2. User creates Campaign
3. User selects contacts:
   Option A: "All contacts from Store X" (simple MVP)
   Option B: Advanced filters "Spent > $500 AND bought Product Y"
4. App creates CampaignContacts from selected Contacts
5. User designs postcard
6. User sends campaign
```

**Advantages:**
- No manual export/import
- Data always fresh (synced hourly)
- Can use Shopify data for targeting (spent, products, tags)
- Multi-campaign: same Contact → many CampaignContacts

---

## 🗄️ DATABASE SCHEMA CHANGES

### New Tables to Create

1. **shopify_stores**
   - Stores OAuth connection per Advertiser
   - Can have multiple stores per Advertiser

2. **contacts**
   - Central customer/contact database
   - Replaces need to duplicate data per campaign

3. **orders**
   - Purchase history
   - Links to contacts
   - JSONB line_items (products purchased)

4. **products**
   - Product catalog
   - JSONB variants (SKUs, sizes, colors)
   - JSONB images (URLs)

5. **sync_jobs**
   - Audit trail of every sync
   - Debug failed syncs
   - Show sync history to users

### Changes to Existing Tables

**campaign_contacts** (add new column):
```ruby
add_column :campaign_contacts, :contact_id, :bigint, null: true
add_foreign_key :campaign_contacts, :contacts
add_index :campaign_contacts, :contact_id
```

**campaigns** (no changes needed, works as-is)

**advertisers** (no changes needed, works as-is)

---

## 🔐 SECURITY NOTES

### Access Token Storage
```ruby
class ShopifyStore < ApplicationRecord
  encrypts :access_token  # Rails 7+ built-in encryption
end
```

Never store tokens in plain text!

### Webhook Verification
```ruby
def verify_shopify_webhook(request)
  hmac = request.headers['X-Shopify-Hmac-SHA256']
  body = request.body.read
  calculated = Base64.strict_encode64(
    OpenSSL::HMAC.digest('sha256', ENV['SHOPIFY_API_SECRET'], body)
  )
  ActiveSupport::SecurityUtils.secure_compare(calculated, hmac)
end
```

Only process webhooks from Shopify!

### Data Scoping
```ruby
# Always scope to current_advertiser
@contacts = current_advertiser.contacts
@orders = current_advertiser.orders

# Never allow cross-tenant access
Contact.where(advertiser_id: params[:advertiser_id]) # ❌ BAD
current_advertiser.contacts.find(params[:id])         # ✅ GOOD
```

---

## 📊 EXAMPLE DATA

### ShopifyStore
```ruby
{
  id: 1,
  advertiser_id: 123,
  shop_domain: "acme.myshopify.com",
  access_token_encrypted: "...",  # encrypted
  name: "Acme Store (US)",
  status: "connected",
  sync_frequency: "hourly",
  initial_sync_completed: true,
  last_sync_at: "2024-10-06 14:00:00",
  last_sync_status: "success"
}
```

### Contact
```ruby
{
  id: 1,
  advertiser_id: 123,
  source_type: "ShopifyStore",
  source_id: 1,
  external_id: "7234567890",  # Shopify customer ID
  email: "jane@example.com",
  first_name: "Jane",
  last_name: "Doe",
  phone: "+1-555-123-4567",
  accepts_marketing: true,
  tags: ["VIP", "Wholesale"],
  total_spent: 1250.00,
  orders_count: 5,
  last_order_at: "2024-10-01",
  default_address: {
    address1: "123 Main St",
    city: "San Francisco",
    state: "CA",
    zip: "94102"
  },
  metadata: {
    shopify_customer_id: "7234567890",
    tax_exempt: false
  }
}
```

### Order
```ruby
{
  id: 1,
  advertiser_id: 123,
  source_type: "ShopifyStore",
  source_id: 1,
  contact_id: 1,  # links to Contact above
  external_id: "5234567890",  # Shopify order ID
  order_number: "#1001",
  email: "jane@example.com",
  financial_status: "paid",
  fulfillment_status: "fulfilled",
  currency: "USD",
  total_price: 125.99,
  line_items: [
    {
      id: "12345",
      title: "Blue T-Shirt",
      quantity: 2,
      price: "25.00"
    }
  ],
  ordered_at: "2024-10-01 10:30:00"
}
```

### CampaignContact (enhanced)
```ruby
{
  id: 1,
  campaign_id: 456,
  contact_id: 1,  # NEW: links to Contact
  first_name: "Jane",  # copied from Contact
  last_name: "Doe",
  email: "jane@example.com",
  address_line1: "123 Main St",
  address_city: "San Francisco",
  address_state: "CA",
  address_zip: "94102",
  status: "delivered",
  lob_postcard_id: "psc_abc123",
  tracking_number: "9400...",
  delivered_at: "2024-10-05"
}
```

---

## 🚀 MIGRATION STRATEGY

### Phase 1: Add new models (non-breaking)
- Create all new tables
- Don't touch existing tables yet
- All Shopify code uses new models
- Existing campaigns still work

### Phase 2: Link CampaignContact to Contact (optional)
- Add `contact_id` column (nullable)
- New campaigns create link automatically
- Old campaigns keep working (null contact_id is fine)
- Gradually backfill if needed

### Phase 3: Eventually...
- All campaigns use Contact → CampaignContact flow
- CSV upload creates Contacts first, then CampaignContacts
- CSV upload becomes just another data source (like Shopify)

---

## ✅ BENEFITS OF THIS ARCHITECTURE

1. **Unified customer database**
   - All customers in one place (contacts table)
   - Regardless of source (Shopify, CSV, future integrations)

2. **Eliminates data duplication**
   - Old way: Store customer data per campaign
   - New way: Store customer once, reference in campaigns

3. **Campaign targeting**
   - "Send to customers who spent > $500"
   - "Send to customers who bought Product X"
   - Can't do this with CSV-only approach

4. **Purchase history**
   - Know who bought what, when
   - Lifetime value calculations
   - RFM segmentation (Recency, Frequency, Monetary)

5. **Future-proof**
   - Add BigCommerce integration? Same Contact/Order/Product tables
   - Add manual upload? Same Contact table with source_type="ManualUpload"
   - Add API integration? Same tables

6. **Multi-store support**
   - Each store syncs independently
   - All data flows into same tables
   - User sees unified view or filtered by store

---

## 📖 NEXT: Implementation Details

See `shopify-implementation-analysis.md` for:
- Full implementation plan
- Week-by-week timeline
- Technical decisions
- Code examples

See `shopify-critical-decisions.md` for:
- Decisions needed before starting
- Quick reference guide
- Recommended MVP scope

