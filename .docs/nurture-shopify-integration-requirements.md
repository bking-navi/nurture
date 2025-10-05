# Shopify Integration Requirements

## Overview

Building Shopify data sync to pull customers, orders, and products into the marketing platform. This integration supports multiple Shopify stores per Advertiser, handles both scheduled syncs and real-time webhooks, and serves as a template for future integrations (manual uploads, other platforms).

**Key principles:**
- Shopify is one of many data sources (manual uploads, future integrations)
- All data sources flow into same tables (contacts, orders, products)
- Multi-store support with aggregated views
- Non-blocking background sync with progress notifications
- Industry-standard practices (follow Klaviyo's approach)

---

## Tech Stack Additions

**New gems needed:**
- `shopify_api` (official Shopify Ruby gem)
- `shopify_app` (Rails engine for OAuth, webhooks)

**Existing stack:**
- Rails 8, PostgreSQL, Sidekiq, Redis
- Loops.so for email notifications

---

## Core Entities

### ShopifyStore

**Purpose:** Represents a connected Shopify store. An Advertiser can have multiple stores.

**Attributes:**
- advertiser_id (foreign key, required)
- shop_domain (string, e.g., "acme.myshopify.com", unique per advertiser)
- access_token_encrypted (text, OAuth token)
- access_scopes (array, granted OAuth scopes)
- name (string, defaults to shop_domain, user can rename)
- status (enum: connected, disconnected, error, syncing)
- last_sync_at (timestamp, when last sync completed)
- last_sync_status (enum: success, failed, partial)
- last_sync_error (text, error message if failed)
- sync_frequency (enum: realtime, every_15_min, hourly, every_6_hours, daily, manual)
- initial_sync_completed (boolean, false until first full sync done)
- shopify_shop_id (bigint, Shopify's internal shop ID)
- shop_owner (string, from Shopify shop data)
- email (string, shop contact email)
- currency (string, shop currency)
- timezone (string, shop timezone)
- plan_name (string, Shopify plan - Basic/Shopify/Advanced/Plus)
- webhooks_installed (boolean, true if webhooks registered)
- created_at, updated_at

**Relationships:**
- belongs_to :advertiser
- has_many :contacts, as: :source
- has_many :orders, as: :source
- has_many :products, as: :source
- has_many :sync_jobs

**Methods:**
- connected? → status is 'connected'
- needs_reconnection? → status is 'disconnected' or 'error'
- display_name → name or shop_domain if name blank
- api_client → returns configured ShopifyAPI::Clients::Rest::Admin client
- sync_now! → triggers immediate sync job
- disconnect! → revokes token, uninstalls webhooks, sets status=disconnected

**Validations:**
- shop_domain: required, format (.myshopify.com), unique within advertiser
- access_token: required (encrypted)
- sync_frequency: required, valid enum value

---

### Contact (Enhanced from Auth Spec)

**Purpose:** A customer/contact from any source. Shopify customers become Contacts.

**Attributes (in addition to what exists):**
- advertiser_id (foreign key, required)
- source_type (string, polymorphic: 'ShopifyStore', 'ManualUpload', 'CsvImport')
- source_id (bigint, polymorphic foreign key)
- external_id (string, e.g., Shopify customer ID, indexed)
- email (string, indexed)
- phone (string)
- first_name (string)
- last_name (string)
- accepts_marketing (boolean, from Shopify marketing consent)
- accepts_marketing_updated_at (timestamp)
- marketing_opt_in_level (string, Shopify's single_opt_in/confirmed_opt_in/unknown)
- tags (array, e.g., ["VIP", "Wholesale"])
- note (text, merchant's private note)
- state (enum: enabled, disabled, invited, declined, default: enabled)
- total_spent (decimal, lifetime value)
- orders_count (integer, total orders)
- last_order_at (timestamp)
- first_order_at (timestamp)
- default_address (jsonb, primary address)
- addresses (jsonb array, all addresses)
- metadata (jsonb, flexible storage for platform-specific data)
- created_at_source (timestamp, when created in source system)
- updated_at_source (timestamp, when last updated in source system)
- created_at, updated_at

**Relationships:**
- belongs_to :advertiser
- belongs_to :source, polymorphic: true (ShopifyStore, ManualUpload, etc.)
- has_many :orders
- has_many :campaign_sends

**Methods:**
- display_name → "#{first_name} #{last_name}" or email
- from_shopify? → source_type == 'ShopifyStore'
- marketable? → accepts_marketing && email.present?
- shopify_url → if from_shopify?, link to Shopify admin

**Validations:**
- advertiser_id: required
- email or phone: at least one required
- email: valid format if present
- external_id: unique within source (composite index: source_type, source_id, external_id)

**Indices:**
- (advertiser_id, email) for fast lookups
- (source_type, source_id, external_id) unique for preventing duplicates
- (advertiser_id, tags) GIN index for tag searches
- (advertiser_id, total_spent) for RFM queries
- (advertiser_id, last_order_at) for recency queries

---

### Order

**Purpose:** A transaction/purchase from any source.

**Attributes:**
- advertiser_id (foreign key, required)
- source_type (string, polymorphic)
- source_id (bigint, polymorphic foreign key)
- contact_id (foreign key, nullable - some orders may not link to contact)
- external_id (string, Shopify order ID, indexed)
- order_number (string, merchant-visible order number, e.g., "#1001")
- email (string, order email - may differ from contact email)
- financial_status (enum: pending, authorized, partially_paid, paid, partially_refunded, refunded, voided)
- fulfillment_status (enum: fulfilled, partial, unfulfilled, null)
- currency (string, e.g., "USD")
- subtotal (decimal)
- total_tax (decimal)
- total_discounts (decimal)
- total_price (decimal, final amount)
- line_items (jsonb array, products purchased)
- discount_codes (jsonb array, codes used)
- shipping_address (jsonb)
- billing_address (jsonb)
- customer_locale (string, e.g., "en")
- tags (array)
- note (text, customer note)
- cancelled_at (timestamp)
- cancel_reason (string)
- closed_at (timestamp, when order finalized)
- metadata (jsonb, platform-specific data)
- ordered_at (timestamp, when order placed)
- created_at_source (timestamp)
- updated_at_source (timestamp)
- created_at, updated_at

**line_items JSONB structure:**
```json
[
  {
    "id": "123456789",
    "product_id": "987654321",
    "variant_id": "111222333",
    "title": "Blue T-Shirt",
    "variant_title": "Large",
    "quantity": 2,
    "price": "25.00",
    "total_discount": "5.00",
    "sku": "BLUE-TEE-L"
  }
]
```

**Relationships:**
- belongs_to :advertiser
- belongs_to :source, polymorphic: true
- belongs_to :contact, optional: true
- has_many :order_line_items (if we need to query line items separately, see note below)

**Methods:**
- from_shopify? → source_type == 'ShopifyStore'
- paid? → financial_status == 'paid'
- refunded? → financial_status.include?('refunded')
- shopify_url → link to Shopify admin

**Validations:**
- advertiser_id: required
- external_id: unique within source
- total_price: required
- currency: required
- ordered_at: required

**Indices:**
- (advertiser_id, ordered_at) for date range queries
- (advertiser_id, contact_id) for customer purchase history
- (source_type, source_id, external_id) unique
- (advertiser_id, financial_status) for filtering paid orders
- GIN index on line_items for product queries (if needed)

**Note on line_items:**
For MVP, store in JSONB. If you need complex queries like "contacts who bought product X", consider extracting to separate OrderLineItem table later. For now, JSONB is faster to implement.

---

### Product

**Purpose:** Products/items available for purchase from any source.

**Attributes:**
- advertiser_id (foreign key, required)
- source_type (string, polymorphic)
- source_id (bigint, polymorphic foreign key)
- external_id (string, Shopify product ID, indexed)
- title (string, required)
- description (text)
- product_type (string, e.g., "T-Shirts")
- vendor (string, brand/vendor name)
- tags (array)
- status (enum: active, archived, draft)
- variants (jsonb array, SKUs/options)
- images (jsonb array, image URLs)
- handle (string, URL slug)
- published_at (timestamp)
- metadata (jsonb)
- created_at_source (timestamp)
- updated_at_source (timestamp)
- created_at, updated_at

**variants JSONB structure:**
```json
[
  {
    "id": "123456789",
    "title": "Small / Blue",
    "sku": "BLUE-TEE-S",
    "price": "25.00",
    "compare_at_price": "30.00",
    "inventory_quantity": 50,
    "inventory_policy": "deny",
    "option1": "Small",
    "option2": "Blue"
  }
]
```

**Relationships:**
- belongs_to :advertiser
- belongs_to :source, polymorphic: true

**Methods:**
- from_shopify?
- shopify_url
- in_stock? → check variants inventory_quantity
- primary_image_url → first image from images array

**Validations:**
- advertiser_id: required
- title: required
- external_id: unique within source

**Indices:**
- (advertiser_id, status) for active products
- (source_type, source_id, external_id) unique
- (advertiser_id, tags) GIN index
- Full-text search on title/description (PostgreSQL tsvector)

---

### SyncJob

**Purpose:** Track sync operations for observability and retry logic.

**Attributes:**
- advertiser_id (foreign key, required)
- shopify_store_id (foreign key, required)
- job_type (enum: full_sync, incremental_sync, customers_only, orders_only, products_only)
- status (enum: pending, running, completed, failed, cancelled)
- started_at (timestamp)
- completed_at (timestamp)
- records_processed (jsonb, e.g., {customers: 1234, orders: 5678, products: 90})
- records_created (jsonb, breakdown of new records)
- records_updated (jsonb, breakdown of updated records)
- records_failed (jsonb, breakdown of errors)
- error_message (text)
- error_details (jsonb, detailed error info)
- estimated_duration (integer, seconds, calculated from record count)
- actual_duration (integer, seconds)
- triggered_by (enum: user, schedule, webhook, system)
- triggered_by_user_id (foreign key to User, nullable)
- sidekiq_jid (string, Sidekiq job ID for tracking)
- created_at, updated_at

**Relationships:**
- belongs_to :advertiser
- belongs_to :shopify_store
- belongs_to :triggered_by_user, class_name: 'User', optional: true

**Methods:**
- in_progress? → status.in?(['pending', 'running'])
- progress_percentage → calculate based on records_processed
- duration → actual_duration or (Time.current - started_at)

**Validations:**
- shopify_store_id: required
- job_type: required
- status: required

**Indices:**
- (shopify_store_id, created_at) for recent jobs
- (status, created_at) for monitoring running jobs

---

## OAuth Connection Flow

### Route Structure

```
GET  /advertisers/:slug/integrations                    → List all integrations
GET  /advertisers/:slug/integrations/shopify            → Shopify integration page
GET  /advertisers/:slug/integrations/shopify/connect    → Start OAuth
GET  /auth/shopify/callback                             → OAuth callback
POST /advertisers/:slug/integrations/shopify/disconnect → Disconnect store
```

### User Flow

**Step 1: User clicks "Connect Shopify" on integrations page**

Route: `/advertisers/:slug/integrations/shopify`

UI shows:
- If no stores connected: "Connect your Shopify store to sync customers, orders, and products"
- "Connect Shopify Store" button
- Info box: "💡 Tip: Managing multiple brands? Create separate Advertisers for better organization. [Learn more]"

**Step 2: Click "Connect Shopify Store" button**

Route: `/advertisers/:slug/integrations/shopify/connect`

Process:
1. Store current_advertiser_id in session (needed after OAuth redirect)
2. Generate OAuth state parameter (CSRF protection)
3. Build Shopify OAuth URL with:
   - shop: (will prompt user to enter their shop domain)
   - scopes: read_customers, read_orders, read_products, read_inventory, write_webhooks
   - redirect_uri: your_app/auth/shopify/callback
   - state: generated CSRF token
4. Redirect to Shopify OAuth consent page

**Step 3: User approves on Shopify, redirects back**

Route: `/auth/shopify/callback?code=xxx&shop=acme.myshopify.com&state=xxx`

Process:
1. Verify state parameter matches session (CSRF check)
2. Exchange code for access_token
3. Fetch shop details from Shopify API (name, email, plan, etc.)
4. Create ShopifyStore record:
   - advertiser_id from session
   - shop_domain from params
   - access_token_encrypted
   - shop details from API
   - status: connected
   - sync_frequency: hourly (default)
   - initial_sync_completed: false
5. Install webhooks (customers/create, customers/update, orders/create, etc.)
6. Set webhooks_installed: true
7. Trigger initial sync job (SyncJob.create + enqueue)
8. Redirect to `/advertisers/:slug/integrations/shopify`
9. Show success message: "Shopify store connected! Initial sync in progress..."

**Step 4: Initial sync completes**

- SyncJob updates status to completed
- Send email notification via Loops: "Your Shopify sync is complete! [View Data]"
- Update ShopifyStore: initial_sync_completed: true, last_sync_at: now

---

## Shopify Integration Page UI

Route: `/advertisers/:slug/integrations/shopify`

### Connected Store(s) View

**For each connected store, show card:**

```
┌─────────────────────────────────────────────────────┐
│ 🟢 acme.myshopify.com                    [Settings ▼]│
│                                                       │
│ Last synced: 2 hours ago (Success)                   │
│                                                       │
│ 👥 1,234 Customers  📦 5,678 Orders  📦 90 Products  │
│                                                       │
│ Sync Frequency: Hourly                    [Sync Now] │
│                                                       │
│ [View in Shopify Admin →]                            │
└─────────────────────────────────────────────────────┘
```

**Settings dropdown includes:**
- Change sync frequency
- Rename store
- Disconnect store
- View sync history

**Status indicators:**
- 🟢 Green: Connected and syncing
- 🟡 Yellow: Syncing in progress
- 🔴 Red: Error or disconnected
- ⚪ Gray: Never synced yet

### Sync History Section

Shows recent SyncJobs for the store:

```
Recent Syncs
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Today, 2:00 PM        Success    1,234 records synced in 3m 24s
Today, 12:00 PM       Success    45 records synced in 12s
Yesterday, 10:00 AM   Failed     API rate limit exceeded [Retry]
Oct 1, 8:00 AM        Success    5,678 records synced in 8m 45s
```

Click a sync to see details:
- Breakdown: X customers, Y orders, Z products
- Created vs updated counts
- Any errors or warnings

### Initial Sync In Progress

While initial_sync_completed is false, show:

```
┌─────────────────────────────────────────────────────┐
│ 🟡 Initial Sync In Progress                          │
│                                                       │
│ We're syncing your Shopify data. This typically      │
│ takes 5-15 minutes depending on your store size.     │
│                                                       │
│ Syncing: Customers ✓  Orders ⏳  Products ...        │
│                                                       │
│ You'll receive an email when the sync is complete.   │
│ Feel free to close this page.                        │
└─────────────────────────────────────────────────────┘
```

(Optional: Real-time progress if easy with Turbo streams, otherwise just status checkmarks)

### Disconnect Confirmation

Modal when clicking "Disconnect store":

```
Disconnect acme.myshopify.com?

This will:
• Stop syncing new data
• Keep existing data in your account
• Remove webhook connections

Your contacts, orders, and campaigns will not be deleted.

You can reconnect anytime.

[Cancel]  [Disconnect Store]
```

### Multi-Store View

If advertiser has multiple stores, show all in list:

```
Connected Stores (2)

[+ Connect Another Store]

┌─────────────────────────┐  ┌─────────────────────────┐
│ 🟢 acme.myshopify.com   │  │ 🟢 acme-eu.myshopify.com│
│ Last synced: 2h ago     │  │ Last synced: 1h ago     │
│ 1,234 customers         │  │ 567 customers           │
└─────────────────────────┘  └─────────────────────────┘
```

Aggregated stats at top:
```
📊 Total Across All Stores
👥 1,801 Customers  📦 7,234 Orders  🎁 150 Products
```

### Banner for Disconnected Store

If store status is 'disconnected' or 'error', show banner at top of app:

```
⚠️ Your Shopify store (acme.myshopify.com) has been disconnected.
   Reconnect to continue syncing data. [Reconnect Now] [Dismiss]
```

---

## Initial Sync Process

### Trigger Points

**Automatic triggers:**
- Immediately after OAuth connection
- User clicks "Sync Now" button
- Scheduled sync (based on sync_frequency)

**Manual triggers:**
- Admin/Owner can trigger from UI

### Sync Job Flow

**Step 1: Create SyncJob record**

```
SyncJob.create(
  advertiser_id: advertiser.id,
  shopify_store_id: store.id,
  job_type: 'full_sync',
  status: 'pending',
  triggered_by: 'user' or 'schedule',
  triggered_by_user_id: current_user&.id
)
```

**Step 2: Enqueue Sidekiq job**

```
ShopifyFullSyncJob.perform_later(sync_job.id)
```

Use dedicated Sidekiq queue: `shopify_sync` (separate from default queue)

**Step 3: Job execution (ShopifyFullSyncJob)**

Pseudocode:
```
1. Update sync_job: status=running, started_at=now
2. Update shopify_store: status=syncing
3. Initialize Shopify API client with access_token
4. Estimate total records (shop.customer_count, order_count, product_count)
5. Update sync_job: estimated_duration (rough: 1000 records/minute)
6. Sync customers (see Customer Sync Strategy below)
7. Sync orders (see Order Sync Strategy below)
8. Sync products (see Product Sync Strategy below)
9. Update sync_job: status=completed, completed_at=now, actual_duration
10. Update shopify_store: status=connected, last_sync_at=now, last_sync_status=success
11. Send completion notification email
12. Broadcast Turbo stream update (if user is watching sync page)
```

**Error handling:**
```
rescue => e
  Update sync_job: status=failed, error_message=e.message
  Update shopify_store: status=error, last_sync_status=failed, last_sync_error
  Log error to monitoring (Sentry, etc.)
  Send error notification email
  Schedule retry (exponential backoff: 5min, 15min, 1hr)
end
```

---

## Data Sync Strategies

### Customer Sync Strategy

**Initial sync (first time):**

```
1. Fetch all customers from Shopify (paginated)
   - Use GraphQL bulk query for efficiency (faster than REST)
   - Or REST API: GET /admin/api/2024-10/customers.json?limit=250&page_info=xxx
   
2. For each customer:
   - Check if exists: Contact.find_by(source: store, external_id: shopify_customer.id)
   - If exists: update attributes
   - If not: create new Contact
   
3. Map Shopify fields to Contact fields:
   - id → external_id
   - email → email
   - phone → phone
   - first_name → first_name
   - last_name → last_name
   - accepts_marketing → accepts_marketing
   - email_marketing_consent.state → marketing_opt_in_level
   - tags → tags (array)
   - note → note
   - state → state
   - total_spent → total_spent
   - orders_count → orders_count
   - last_order_date → last_order_at
   - default_address → default_address (jsonb)
   - addresses → addresses (jsonb array)
   - created_at → created_at_source
   - updated_at → updated_at_source
   - Everything else → metadata (jsonb)
   
4. Batch insert/update for performance (use activerecord-import gem)
   - Process in chunks of 500-1000 records
   - Use upsert to handle duplicates
   
5. Update sync_job.records_processed after each batch
```

**Incremental sync (subsequent syncs):**

```
1. Fetch customers updated since last_sync_at
   - GET /customers.json?updated_at_min=2024-10-01T00:00:00Z
   
2. Same mapping and upsert logic
   
3. Much faster (only changed records)
```

**Deleted customers:**

Shopify doesn't provide a "deleted customers" API. Two options:

**Option A (Simple):** Don't delete. Keep all historical data.

**Option B (Complete):** 
- Track all customer IDs during sync
- After sync, find Contacts from this store not in current batch
- Mark as state='disabled' or soft-delete

Recommend Option A for MVP (keeps historical campaign data intact).

### Order Sync Strategy

**Initial sync (60-day limitation):**

```
1. Fetch orders from last 60 days
   - GET /admin/api/2024-10/orders.json?status=any&limit=250&created_at_min=60_days_ago
   
2. For each order:
   - Find or create Contact by email (link order to contact)
   - Check if Order exists: find_by(source: store, external_id: shopify_order.id)
   - Upsert Order record
   
3. Map Shopify fields:
   - id → external_id
   - name → order_number (e.g., "#1001")
   - email → email
   - financial_status → financial_status
   - fulfillment_status → fulfillment_status
   - currency → currency
   - subtotal_price → subtotal
   - total_tax → total_tax
   - total_discounts → total_discounts
   - total_price → total_price
   - line_items → line_items (jsonb array)
   - discount_codes → discount_codes (jsonb array)
   - shipping_address → shipping_address (jsonb)
   - billing_address → billing_address (jsonb)
   - customer_locale → customer_locale
   - tags → tags
   - note → note
   - cancelled_at → cancelled_at
   - cancel_reason → cancel_reason
   - closed_at → closed_at
   - created_at → ordered_at AND created_at_source
   - updated_at → updated_at_source
   
4. Batch upsert for performance
```

**After sync, apply for historical access:**

Show in UI:
```
📋 Limited History
We've synced the last 60 days of orders. To access your full order 
history, we need to request extended access from Shopify.

[Request Historical Access]
```

When clicked:
- Guide user through Shopify's Extended Scopes application
- Or auto-submit if possible via API
- Once approved, trigger historical backfill job

**Historical backfill job (after approval):**

```
1. Fetch all orders (no date limit)
2. Same mapping logic
3. May take much longer (show progress)
```

**Incremental sync:**

```
1. Fetch orders updated since last_sync_at
2. Same upsert logic
3. Much faster
```

**Linking orders to contacts:**

```
If order.email matches contact.email within same advertiser:
  order.contact_id = contact.id
Else:
  order.contact_id = nil (order without matched contact)
  
Option: Create contact from order if doesn't exist (depends on business logic)
```

### Product Sync Strategy

**Initial sync:**

```
1. Fetch all products
   - GET /admin/api/2024-10/products.json?limit=250
   
2. For each product:
   - Check if exists: find_by(source: store, external_id: shopify_product.id)
   - Upsert Product record
   
3. Map Shopify fields:
   - id → external_id
   - title → title
   - body_html → description
   - product_type → product_type
   - vendor → vendor
   - tags → tags (comma-separated string → array)
   - status → status
   - variants → variants (jsonb array)
   - images → images (jsonb array of URLs)
   - handle → handle
   - published_at → published_at
   - created_at → created_at_source
   - updated_at → updated_at_source
   
4. Batch upsert
```

**Incremental sync:**

```
Same as customers - fetch products updated since last_sync_at
```

**Products sync less frequently:**

Products change rarely compared to orders. Consider:
- User can set separate sync schedule for products (daily vs hourly for orders)
- Or products only sync when user clicks "Sync Products" button
- Or smart sync: check updated_at timestamps first, skip if no changes

For MVP: sync products on same schedule as customers/orders (simpler).

---

## Webhook Integration (Real-Time Updates)

### Why Webhooks?

**Benefits:**
- Near real-time data (vs waiting for next scheduled sync)
- Reduces API calls (Shopify notifies you of changes)
- Better UX (new order appears immediately)

**Trade-offs:**
- More complex (need webhook endpoint, verification, idempotency)
- Webhooks can be unreliable (need to handle failures)

**Recommendation:** Implement webhooks for MVP because Shopify makes it easy and your customers expect real-time data for a mid-enterprise product.

### Webhooks to Register

**During OAuth connection, install these webhooks:**

```
customers/create       → Create new Contact
customers/update       → Update existing Contact
customers/delete       → Handle deletion (GDPR)
orders/create          → Create new Order
orders/updated         → Update existing Order
orders/cancelled       → Mark Order as cancelled
products/create        → Create new Product
products/update        → Update existing Product
products/delete        → Remove or archive Product
shop/update            → Update ShopifyStore metadata (plan changes, etc.)
app/uninstalled        → Merchant uninstalled app (disconnect store)
```

**Use shopify_app gem to manage webhooks:**
- Automatically registers webhooks after OAuth
- Handles webhook verification (HMAC signature)
- Provides controllers for each webhook type

### Webhook Endpoint Structure

Route: `POST /webhooks/shopify/:topic`

Example: `POST /webhooks/shopify/customers_create`

**Webhook processing pattern:**

```
1. Verify HMAC signature (shopify_app does this)
2. Extract shop domain and topic from headers
3. Find ShopifyStore by shop_domain
4. Parse webhook payload (JSON)
5. Enqueue background job (don't process in HTTP request)
   - ShopifyWebhookJob.perform_later(store.id, topic, payload)
6. Return 200 OK immediately (within 5 seconds or Shopify retries)
```

**Background job (ShopifyWebhookJob):**

```
def perform(shopify_store_id, topic, payload)
  store = ShopifyStore.find(shopify_store_id)
  
  case topic
  when 'customers/create', 'customers/update'
    upsert_contact_from_webhook(store, payload)
  when 'customers/delete'
    handle_customer_deletion(store, payload)
  when 'orders/create', 'orders/updated'
    upsert_order_from_webhook(store, payload)
  when 'orders/cancelled'
    cancel_order(store, payload)
  when 'products/create', 'products/update'
    upsert_product_from_webhook(store, payload)
  when 'products/delete'
    archive_product(store, payload)
  when 'app/uninstalled'
    disconnect_store(store)
  end
end
```

**Idempotency:**

Webhooks can be delivered multiple times. Handle with:
- Upsert logic (find_or_create + update)
- Check updated_at_source - if webhook's timestamp is older than DB, skip
- Use external_id to prevent duplicates

### Webhook vs Scheduled Sync

**If sync_frequency is 'realtime':**
- Webhooks are primary data source
- Still run daily full sync as backup (catch any missed webhooks)
- Full sync compares timestamps, only updates if Shopify data is newer

**If sync_frequency is 'hourly' or longer:**
- Webhooks still process immediately for real-time feel
- Scheduled sync ensures completeness
- Webhooks are "best effort," sync is "source of truth"

---

## Rate Limiting & API Optimization

### Shopify API Limits

**REST API:**
- Basic Shopify: 2 calls/second
- Shopify/Advanced: 4 calls/second
- Plus: 4 calls/second (can request higher)
- Leaky bucket algorithm (can burst, then slows down)

**GraphQL API:**
- Points-based system (50 points/second)
- More complex queries cost more points
- Can request calculated cost before running query

### Handling Rate Limits

**Strategy:**

```
1. Use shopify_api gem's built-in rate limiting
   - Gem tracks requests and auto-sleeps when approaching limit
   
2. For bulk operations (initial sync), use GraphQL Bulk API
   - Can fetch 100K+ records without hitting rate limits
   - Asynchronous: Shopify generates file, you download
   - Much faster for large datasets
   
3. If rate limited (429 response):
   - Parse Retry-After header
   - Sleep for that duration
   - Retry request
   - Update SyncJob with "Rate limited, resuming in X seconds" message
   
4. Track API usage:
   - Log every API call with response time
   - Monitor which stores consume most API calls
   - Show "API health" indicator in UI
```

**Implementation:**

```
# Wrap API calls
def fetch_with_retry(url, max_retries: 3)
  retries = 0
  begin
    response = shopify_api_client.get(url)
    response
  rescue ShopifyAPI::Errors::HttpResponseError => e
    if e.code == 429 && retries < max_retries
      retry_after = e.response.headers['Retry-After']&.to_i || 2
      sleep(retry_after)
      retries += 1
      retry
    else
      raise
    end
  end
end
```

**UX:**

If sync slows due to rate limiting:
- Update sync progress: "Syncing (rate limited, slowing down)..."
- Don't show error - this is normal
- Estimated time increases automatically

---

## Sync Scheduling

### Sidekiq Scheduled Jobs

**Use sidekiq-cron or similar for recurring syncs:**

```
ShopifyStore.where(sync_frequency: 'hourly', status: 'connected').each do |store|
  ShopifyIncrementalSyncJob.perform_later(store.id)
end
```

**Schedule:**
- Every 15 min: Run for stores with sync_frequency='every_15_min'
- Every hour: Run for stores with sync_frequency='hourly'
- Every 6 hours: sync_frequency='every_6_hours'
- Daily at 2am: sync_frequency='daily'
- Realtime: Only webhooks + daily full sync

**Stagger execution:**

Don't sync all stores at same time (avoid thundering herd).

```
ShopifyStore.where(sync_frequency: 'hourly').find_each.with_index do |store, i|
  # Stagger over 60 minutes
  delay = (i % 60).minutes
  ShopifyIncrementalSyncJob.set(wait: delay).perform_later(store.id)
end
```

### Full Sync vs Incremental Sync

**Full sync (ShopifyFullSyncJob):**
- Fetches ALL records (or paginated with cursor)
- Used for: initial connection, manual "Sync Now", weekly validation
- Takes longer (5-30+ minutes for large stores)
- Job type: 'full_sync'

**Incremental sync (ShopifyIncrementalSyncJob):**
- Fetches only records updated since last_sync_at
- Used for: scheduled syncs (hourly, daily, etc.)
- Much faster (seconds to minutes)
- Job type: 'incremental_sync'

**Separate sync jobs for different resources:**

Allow users to sync customers/orders/products independently:

```
ShopifyCustomersSyncJob.perform_later(store.id)
ShopifyOrdersSyncJob.perform_later(store.id)
ShopifyProductsSyncJob.perform_later(store.id)
```

Useful for:
- "I only need to refresh products" (faster than full sync)
- Debugging specific sync issues
- Different schedules (products daily, orders hourly)

---

## Data Model Considerations

### Polymorphic Source

**Why polymorphic?**

Supports multiple data sources (Shopify, manual uploads, other integrations):

```
Contact
  - source_type: 'ShopifyStore', 'ManualUpload', 'CsvImport', 'BigCommerce', etc.
  - source_id: ID of the source record
```

**Queries:**

```ruby
# All contacts from Shopify
Contact.where(source_type: 'ShopifyStore')

# All contacts from a specific store
Contact.where(source_type: 'ShopifyStore', source_id: store.id)

# All contacts for advertiser (regardless of source)
Contact.where(advertiser_id: advertiser.id)
```

**Benefits:**
- Future-proof for other integrations
- Manual uploads fit same model
- Segment builder doesn't care about source

### Handling Duplicates Across Sources

**Scenario:** Same customer in multiple Shopify stores, or in Shopify + manual upload.

**Options:**

**Option A: Keep separate (recommended for MVP)**
- Each source has its own Contact record
- Even if same email, they're separate rows
- Simpler logic, no merge conflicts
- Segments can filter by source if needed

**Option B: Merge by email**
- One Contact per unique email within Advertiser
- source_type/source_id becomes arrays (or separate ContactSources join table)
- Complex: which source is "primary"? What if data conflicts?

**Recommendation:** Option A for MVP. Most merchants have one main store. Add merging later if customers request it.

### Metadata Field Usage

**metadata (JSONB)** stores platform-specific data that doesn't fit main schema:

**For Shopify contacts:**
```json
{
  "shopify_customer_id": "123456789",
  "tax_exempt": false,
  "verified_email": true,
  "admin_graphql_api_id": "gid://shopify/Customer/123456789"
}
```

**For Shopify orders:**
```json
{
  "shopify_order_id": "987654321",
  "order_status_url": "https://acme.myshopify.com/...",
  "source_name": "web",
  "referring_site": "https://google.com"
}
```

**Query example:**

```ruby
# Find contacts with tax_exempt=true
Contact.where("metadata->>'tax_exempt' = 'true'")
```

### Indexing Strategy

**Critical indices:**

```sql
-- Contact lookups
CREATE INDEX idx_contacts_advertiser_email ON contacts(advertiser_id, email);
CREATE UNIQUE INDEX idx_contacts_source_external ON contacts(source_type, source_id, external_id);
CREATE INDEX idx_contacts_tags ON contacts USING GIN(tags);

-- Order queries
CREATE INDEX idx_orders_advertiser_ordered_at ON orders(advertiser_id, ordered_at DESC);
CREATE INDEX idx_orders_contact ON orders(advertiser_id, contact_id);
CREATE UNIQUE INDEX idx_orders_source_external ON orders(source_type, source_id, external_id);

-- Product searches
CREATE INDEX idx_products_advertiser_status ON products(advertiser_id, status);
CREATE UNIQUE INDEX idx_products_source_external ON products(source_type, source_id, external_id);

-- Full-text search on products
CREATE INDEX idx_products_search ON products USING GIN(to_tsvector('english', title || ' ' || COALESCE(description, '')));

-- Sync job monitoring
CREATE INDEX idx_sync_jobs_status ON sync_jobs(status, created_at);
CREATE INDEX idx_sync_jobs_store ON sync_jobs(shopify_store_id, created_at DESC);
```

---

## Error Handling & Resilience

### Common Failure Scenarios

**1. OAuth token expired/revoked**

**Detection:** API call returns 401 Unauthorized

**Response:**
- Update ShopifyStore: status='disconnected', last_sync_error='Token expired'
- Show banner: "Reconnect your Shopify store"
- Send email notification to advertiser owner/admins
- Stop scheduled syncs for this store

**Recovery:** User clicks "Reconnect," goes through OAuth again

---

**2. Shopify API rate limit exceeded**

**Detection:** API returns 429 Too Many Requests

**Response:**
- Parse Retry-After header
- Sleep for specified duration
- Resume sync automatically
- Update SyncJob: "Rate limited, resuming..."

**Don't treat as error** - this is expected behavior

---

**3. Invalid/malformed data from Shopify**

**Detection:** Validation error when creating Contact/Order/Product

**Response:**
- Log the error with full payload
- Increment sync_job.records_failed
- Continue processing other records (don't fail entire sync)
- Store error in sync_job.error_details: `{record_id: "123", error: "Email invalid"}`
- Show in sync history: "Completed with 3 errors" (clickable to see details)

**Recovery:** Fix validation rules, re-sync

---

**4. Network timeouts**

**Detection:** HTTP timeout error

**Response:**
- Retry with exponential backoff (3 attempts)
- If all retries fail, mark SyncJob as failed
- Schedule automatic retry in 15 minutes
- After 3 failed automatic retries, stop and notify user

---

**5. Shopify store deleted/uninstalled app**

**Detection:** Webhook `app/uninstalled` or API returns 404

**Response:**
- Update ShopifyStore: status='disconnected'
- Uninstall webhooks (cleanup)
- Keep all data (don't delete contacts/orders)
- Show banner: "Your Shopify store has been disconnected"
- Send email notification

**Recovery:** User must reconnect (new OAuth)

---

**6. Database errors (deadlock, constraint violation)**

**Detection:** ActiveRecord::RecordInvalid, PG::UniqueViolation, etc.

**Response:**
- Catch and log error
- For unique violations: likely duplicate, skip record
- For deadlocks: retry transaction (Rails does this automatically)
- If persistent, fail sync and notify engineering team (not user's fault)

---

### Retry Logic

**Automatic retries for transient errors:**

```ruby
def sync_with_retry(max_retries: 3)
  retries = 0
  begin
    yield
  rescue ShopifyAPI::Errors::HttpResponseError => e
    if e.code.in?([429, 503, 504]) && retries < max_retries
      retries += 1
      sleep_duration = 2 ** retries # Exponential backoff: 2s, 4s, 8s
      sleep(sleep_duration)
      retry
    else
      raise
    end
  end
end
```

**Scheduled retry for failed syncs:**

If SyncJob fails, automatically schedule retry:
- First retry: 5 minutes later
- Second retry: 15 minutes later
- Third retry: 1 hour later
- After 3 failures: stop, notify user

---

### Monitoring & Alerting

**Metrics to track:**

```
- Sync success rate (% of syncs that complete)
- Average sync duration
- API error rate per store
- Webhook delivery success rate
- Queue depth (Sidekiq job backlog)
```

**Alerts to set up:**

```
- Alert if >10% of syncs failing across all stores
- Alert if any store has 3+ consecutive failed syncs
- Alert if Sidekiq queue depth >1000 jobs
- Alert if webhook processing >5 seconds (blocks Shopify)
```

**Use existing monitoring tools:**
- Sidekiq Web UI (built-in dashboard)
- Sentry or Rollbar for error tracking
- Render metrics for app performance

---

## Email Notifications

### Sync Complete (Success)

**Template ID:** shopify_sync_complete

**Trigger:** SyncJob completes with status='completed' AND initial_sync_completed changed to true

**Recipients:** Advertiser owner + anyone who triggered the sync

**Variables:**
```
shop_name: "acme.myshopify.com"
customers_synced: 1234
orders_synced: 5678
products_synced: 90
duration: "8 minutes"
view_url: link to integrations page
```

**Subject:** "Your Shopify sync is complete!"

**Content:**
```
Great news! We've finished syncing your Shopify store.

Here's what we imported:
• 1,234 customers
• 5,678 orders
• 90 products

This took 8 minutes. You can now start building campaigns!

[View Your Data]
```

---

### Sync Failed

**Template ID:** shopify_sync_failed

**Trigger:** SyncJob status='failed' AND automatic retries exhausted

**Recipients:** Advertiser owner + admins

**Variables:**
```
shop_name: "acme.myshopify.com"
error_message: "API rate limit exceeded"
retry_url: link to retry button
support_url: link to contact support
```

**Subject:** "Action needed: Shopify sync failed"

**Content:**
```
We encountered an issue syncing your Shopify store (acme.myshopify.com).

Error: API rate limit exceeded

We've automatically retried 3 times. Please try again manually or contact support if this persists.

[Retry Sync] [Contact Support]
```

---

### Store Disconnected

**Template ID:** shopify_store_disconnected

**Trigger:** ShopifyStore status changes to 'disconnected'

**Recipients:** Advertiser owner + admins

**Variables:**
```
shop_name: "acme.myshopify.com"
reason: "OAuth token expired" or "App uninstalled" or "API error"
reconnect_url: link to reconnect
```

**Subject:** "Your Shopify store has been disconnected"

**Content:**
```
Your Shopify store (acme.myshopify.com) has been disconnected.

Reason: OAuth token expired

Your existing data is safe, but we won't be able to sync new customers or orders until you reconnect.

[Reconnect Shopify]
```

---

## Security Considerations

### Access Token Storage

**Encrypt at rest:**

Use Rails 7+ built-in encryption:

```ruby
class ShopifyStore < ApplicationRecord
  encrypts :access_token
end
```

Or use attr_encrypted gem for Rails <7.

**Never log tokens:**
- Filter from logs (Rails config.filter_parameters)
- Don't display in UI (even to admins)
- Don't include in error messages

---

### Webhook Verification

**Shopify signs webhooks with HMAC:**

```ruby
def verify_webhook(request)
  hmac_header = request.headers['X-Shopify-Hmac-SHA256']
  data = request.body.read
  calculated_hmac = Base64.strict_encode64(
    OpenSSL::HMAC.digest('sha256', SHOPIFY_API_SECRET, data)
  )
  
  ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
end
```

shopify_app gem handles this automatically.

**If verification fails:**
- Return 401 Unauthorized
- Log suspicious activity
- Don't process webhook

---

### GDPR Compliance

**Customer deletion webhook:**

When merchant deletes customer in Shopify (GDPR request):

Webhook: `customers/redact`

**Response:**
```
1. Find Contact by external_id
2. Option A: Hard delete (recommended for GDPR)
   - Delete Contact record
   - Cascade delete related CampaignSends
   - Keep Orders (anonymized: set contact_id=null, redact email)
   
3. Option B: Anonymize
   - Redact PII: email="redacted@example.com", name="[Deleted]", phone=null
   - Keep for historical reporting
   
4. Log deletion for audit trail
```

**Shop deletion webhook:**

Webhook: `shop/redact`

**Response:**
```
1. Find ShopifyStore
2. Disconnect and delete store record
3. Option: delete all related Contacts/Orders/Products
   Or: keep data but mark source_id as null (orphaned data)
   
Defer to advertiser preference (setting in UI)
```

---

### API Scope Permissions

**Request minimal scopes needed:**

```
read_customers
read_orders
read_products
read_inventory  (for product stock levels)
write_webhooks  (to register webhooks)
```

**Don't request:**
- write_customers (not needed)
- write_orders (not needed)
- read_price_rules, read_discounts (unless building discount features)

**Why minimal scopes:**
- Faster merchant approval (less scary)
- Security best practice (principle of least privilege)
- Easier to audit

---

## UI Components & Pages

### Integrations Index Page

Route: `/advertisers/:slug/integrations`

**Purpose:** Central hub for all integrations (Shopify, future: BigCommerce, manual uploads, etc.)

**Layout:**

```
Integrations

Connect your data sources to power campaigns and analytics.

Available Integrations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────────────────────────┐
│ 🛍️  Shopify                          [Connected] │
│                                                   │
│ Sync customers, orders, and products from your   │
│ Shopify store.                                   │
│                                                   │
│ 2 stores connected • Last synced 1 hour ago      │
│                                                   │
│ [Manage →]                                       │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ 📄  CSV Upload                      [Coming Soon] │
│                                                   │
│ Manually upload customer lists via CSV files.    │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ 🛒  BigCommerce                     [Coming Soon] │
│                                                   │
│ Sync data from your BigCommerce store.           │
└──────────────────────────────────────────────────┘
```

---

### Shopify Integration Page

Route: `/advertisers/:slug/integrations/shopify`

**See "Shopify Integration Page UI" section above for detailed mockup**

---

### Sync History Detail Modal

Clicking a sync job opens modal:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sync Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Store: acme.myshopify.com
Started: Oct 3, 2024 at 2:00 PM
Duration: 3 minutes 24 seconds
Status: ✅ Success

Records Processed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Customers:  1,234 synced (120 new, 1,114 updated)
Orders:     5,678 synced (45 new, 5,633 updated)
Products:   90 synced (0 new, 90 updated)

[Close]
```

**If sync failed:**

```
Status: ❌ Failed

Error: API rate limit exceeded after 3 retries

We'll automatically retry this sync in 15 minutes.

[Retry Now]  [Contact Support]  [Close]
```

---

### Banner for Disconnected Store

Appears at top of all pages in advertiser when store is disconnected:

```
⚠️ Action Required: Your Shopify store (acme.myshopify.com) is disconnected.
   Data sync has stopped. [Reconnect Now] [Dismiss for 24h]
```

Click "Reconnect Now" → redirects to OAuth flow

Click "Dismiss" → hides banner for 24 hours (stored in session)

---

### Settings Dropdown (on Shopify page)

Clicking "Settings" dropdown on a store card shows:

```
Change Sync Frequency
  → Realtime (webhooks)
  → Every 15 minutes
  → Hourly (recommended)
  → Every 6 hours
  → Daily
  → Manual only

Rename Store
  → Opens inline edit field

View Sync History
  → Opens full history page

Disconnect Store
  → Opens confirmation modal
```

---

## Database Migrations

### Migration Order

**1. Create shopify_stores table**

```ruby
create_table :shopify_stores do |t|
  t.references :advertiser, null: false, foreign_key: true, index: true
  t.string :shop_domain, null: false
  t.text :access_token_encrypted, null: false
  t.string :access_scopes, array: true, default: []
  t.string :name
  t.integer :status, default: 0, null: false  # enum
  t.datetime :last_sync_at
  t.integer :last_sync_status  # enum
  t.text :last_sync_error
  t.integer :sync_frequency, default: 2, null: false  # enum (hourly)
  t.boolean :initial_sync_completed, default: false
  t.bigint :shopify_shop_id
  t.string :shop_owner
  t.string :email
  t.string :currency
  t.string :timezone
  t.string :plan_name
  t.boolean :webhooks_installed, default: false
  t.timestamps
end

add_index :shopify_stores, [:advertiser_id, :shop_domain], unique: true
```

---

**2. Create contacts table (or alter if exists from auth spec)**

```ruby
create_table :contacts do |t|
  t.references :advertiser, null: false, foreign_key: true, index: true
  t.string :source_type, null: false
  t.bigint :source_id, null: false
  t.string :external_id, null: false
  t.string :email
  t.string :phone
  t.string :first_name
  t.string :last_name
  t.boolean :accepts_marketing, default: false
  t.datetime :accepts_marketing_updated_at
  t.string :marketing_opt_in_level
  t.string :tags, array: true, default: []
  t.text :note
  t.integer :state, default: 0  # enum
  t.decimal :total_spent, precision: 10, scale: 2, default: 0
  t.integer :orders_count, default: 0
  t.datetime :last_order_at
  t.datetime :first_order_at
  t.jsonb :default_address
  t.jsonb :addresses, default: []
  t.jsonb :metadata, default: {}
  t.datetime :created_at_source
  t.datetime :updated_at_source
  t.timestamps
end

add_index :contacts, [:advertiser_id, :email]
add_index :contacts, [:source_type, :source_id, :external_id], unique: true, name: 'idx_contacts_source_external'
add_index :contacts, :tags, using: :gin
add_index :contacts, [:advertiser_id, :total_spent]
add_index :contacts, [:advertiser_id, :last_order_at]
```

---

**3. Create orders table**

```ruby
create_table :orders do |t|
  t.references :advertiser, null: false, foreign_key: true, index: true
  t.string :source_type, null: false
  t.bigint :source_id, null: false
  t.references :contact, foreign_key: true, index: true
  t.string :external_id, null: false
  t.string :order_number
  t.string :email
  t.integer :financial_status  # enum
  t.integer :fulfillment_status  # enum
  t.string :currency, null: false
  t.decimal :subtotal, precision: 10, scale: 2
  t.decimal :total_tax, precision: 10, scale: 2
  t.decimal :total_discounts, precision: 10, scale: 2
  t.decimal :total_price, precision: 10, scale: 2, null: false
  t.jsonb :line_items, default: []
  t.jsonb :discount_codes, default: []
  t.jsonb :shipping_address
  t.jsonb :billing_address
  t.string :customer_locale
  t.string :tags, array: true, default: []
  t.text :note
  t.datetime :cancelled_at
  t.string :cancel_reason
  t.datetime :closed_at
  t.jsonb :metadata, default: {}
  t.datetime :ordered_at, null: false
  t.datetime :created_at_source
  t.datetime :updated_at_source
  t.timestamps
end

add_index :orders, [:advertiser_id, :ordered_at]
add_index :orders, [:advertiser_id, :contact_id]
add_index :orders, [:source_type, :source_id, :external_id], unique: true, name: 'idx_orders_source_external'
add_index :orders, [:advertiser_id, :financial_status]
add_index :orders, :line_items, using: :gin
```

---

**4. Create products table**

```ruby
create_table :products do |t|
  t.references :advertiser, null: false, foreign_key: true, index: true
  t.string :source_type, null: false
  t.bigint :source_id, null: false
  t.string :external_id, null: false
  t.string :title, null: false
  t.text :description
  t.string :product_type
  t.string :vendor
  t.string :tags, array: true, default: []
  t.integer :status, default: 0  # enum
  t.jsonb :variants, default: []
  t.jsonb :images, default: []
  t.string :handle
  t.datetime :published_at
  t.jsonb :metadata, default: {}
  t.datetime :created_at_source
  t.datetime :updated_at_source
  t.timestamps
end

add_index :products, [:advertiser_id, :status]
add_index :products, [:source_type, :source_id, :external_id], unique: true, name: 'idx_products_source_external'
add_index :products, :tags, using: :gin
```

---

**5. Create sync_jobs table**

```ruby
create_table :sync_jobs do |t|
  t.references :advertiser, null: false, foreign_key: true, index: true
  t.references :shopify_store, null: false, foreign_key: true, index: true
  t.integer :job_type, null: false  # enum
  t.integer :status, default: 0, null: false  # enum
  t.datetime :started_at
  t.datetime :completed_at
  t.jsonb :records_processed, default: {}
  t.jsonb :records_created, default: {}
  t.jsonb :records_updated, default: {}
  t.jsonb :records_failed, default: {}
  t.text :error_message
  t.jsonb :error_details, default: {}
  t.integer :estimated_duration
  t.integer :actual_duration
  t.integer :triggered_by, default: 0  # enum
  t.references :triggered_by_user, foreign_key: { to_table: :users }
  t.string :sidekiq_jid
  t.timestamps
end

add_index :sync_jobs, [:shopify_store_id, :created_at]
add_index :sync_jobs, [:status, :created_at]
```

---

## Implementation Timeline

### Week 3: Shopify OAuth & Initial Sync (Days 1-5)

**Day 1: Setup & OAuth**
- Add shopify_api and shopify_app gems
- Configure Shopify app credentials
- Create ShopifyStore model + migration
- Build OAuth flow (connect, callback, disconnect)
- Test: can connect a test Shopify store

**Day 2: API Client & Data Models**
- Create Contact, Order, Product models + migrations
- Update existing Contact model with new fields (if needed)
- Build Shopify API client wrapper
- Test: can fetch customers/orders/products from Shopify API

**Day 3: Initial Sync Job (Customers)**
- Create ShopifyFullSyncJob
- Implement customer sync logic (fetch, map, upsert)
- Handle pagination
- Create SyncJob tracking
- Test: can sync 1000+ test customers

**Day 4: Initial Sync Job (Orders & Products)**
- Implement order sync logic
- Implement product sync logic
- Handle 60-day order limitation
- Test: full sync of test store completes
- Add error handling and retries

**Day 5: UI for Integration**
- Build integrations index page
- Build Shopify integration page
- Show connected stores
- Display sync status and history
- "Connect Shopify" and "Sync Now" buttons
- Test: user can connect store via UI and see sync progress

---

### Week 4: Webhooks & Incremental Sync (Days 1-5)

**Day 1: Webhook Setup**
- Configure shopify_app webhooks
- Create webhook endpoints (customers, orders, products)
- Implement webhook verification
- Test: webhooks receive and verify correctly

**Day 2: Webhook Processing**
- Create ShopifyWebhookJob
- Implement customer webhook handlers (create, update, delete)
- Implement order webhook handlers
- Implement product webhook handlers
- Test: new customer in Shopify appears in DB immediately

**Day 3: Incremental Sync**
- Create ShopifyIncrementalSyncJob
- Implement "fetch since last_sync_at" logic
- Much faster than full sync
- Test: incremental sync only fetches new/updated records

**Day 4: Scheduling & Rate Limiting**
- Set up Sidekiq cron for scheduled syncs
- Implement sync frequency options (hourly, daily, etc.)
- Add rate limit handling with retry
- Test: scheduled syncs run automatically

**Day 5: Polish & Error Handling**
- Implement all error scenarios (token expired, rate limit, etc.)
- Add disconnected store banner
- Add email notifications (sync complete, sync failed, disconnected)
- Test: error recovery works correctly

---

### Week 5: Multi-Store & Observability (Days 1-3)

**Day 1: Multi-Store Support**
- UI for multiple connected stores
- Aggregated stats across stores
- Store naming/management
- Test: can connect 2+ stores, see aggregated data

**Day 2: Sync Observability**
- Enhanced sync history UI
- Detailed sync job modal (records processed, errors, etc.)
- Real-time progress (optional, with Turbo Streams)
- Test: user can see exactly what synced and any errors

**Day 3: Historical Order Access**
- UI prompt for requesting historical access
- Historical backfill job (for post-approval)
- Test: can sync orders beyond 60 days after approval

---

### Week 6: Testing & Deployment (Days 1-2)

**Day 1: Integration Testing**
- Test with real Shopify stores (create test stores)
- Test large stores (10K+ customers)
- Test rate limiting scenarios
- Test webhook delivery
- Test error recovery

**Day 2: Deploy & Monitor**
- Deploy to Render production
- Set up monitoring (Sidekiq dashboard, error tracking)
- Document for internal team
- Prepare demo for stakeholders

---

## Success Criteria

### MVP Complete When:

- [ ] User can connect Shopify store via OAuth
- [ ] Initial sync imports all customers, last 60 days of orders, all products
- [ ] User receives email when sync completes
- [ ] Incremental syncs run on schedule (hourly by default)
- [ ] Webhooks provide real-time updates
- [ ] User can view sync history and status
- [ ] User can manually trigger sync
- [ ] User can disconnect store
- [ ] Multi-store support works (connect 2+ stores)
- [ ] Aggregated stats across stores display correctly
- [ ] Rate limiting handled gracefully
- [ ] Errors show helpful messages and retry automatically
- [ ] Disconnected store banner appears
- [ ] All data properly scoped to advertiser (no cross-tenant leaks)
- [ ] Performance acceptable (10K customers sync in <5 minutes)

---

## Questions for Future Phases

**Not needed for MVP, but plan for:**

1. **Should contacts be deduplicated across sources?**
   - Same email in Shopify + manual upload = 1 or 2 contacts?
   - Affects segment accuracy

2. **How to handle refunded orders?**
   - Should total_spent subtract refunds?
   - Should refunded orders be excluded from order_count?

3. **Product inventory tracking?**
   - Real-time inventory for "back in stock" campaigns?
   - Or snapshot at sync time is enough?

4. **Customer segments based on product purchases?**
   - "Customers who bought product X but not product Y"
   - Requires querying line_items JSONB (slow) or extracting to OrderLineItems table

5. **Multi-currency handling?**
   - If stores in different countries, normalize to USD?
   - Or keep native currency and convert for analytics?

6. **Archived/deleted products?**
   - Keep forever for historical orders?
   - Or clean up after X months?

7. **Custom metafields?**
   - Let users select which metafields to sync?
   - Or always sync all into metadata?

8. **API usage analytics?**
   - Show "API calls used this month" per store?
   - Warn if approaching Shopify limits?

---

## Conclusion

This Shopify integration spec provides:

- **Production-ready OAuth flow** with proper token storage
- **Efficient data syncing** using REST/GraphQL APIs with rate limit handling
- **Real-time updates** via webhooks for immediate data freshness
- **Multi-store support** with aggregated views
- **Comprehensive error handling** and automatic retries
- **User-friendly UI** with sync status, history, and observability
- **Scalable architecture** that supports future integrations (manual uploads, other platforms)
- **Security best practices** (encrypted tokens, webhook verification, GDPR compliance)

The polymorphic source model makes it easy to add other data sources later (CSV uploads, BigCommerce, WooCommerce, etc.) while keeping segment building and campaign logic source-agnostic.

**Timeline: 3-4 weeks to go from zero to production Shopify integration.**

Combined with the 2-week auth/multitenancy foundation, you'll have a working marketing platform with real Shopify data in 5-6 weeks total - faster than the 15-person team has accomplished in 3 months.

Ready to start building?
