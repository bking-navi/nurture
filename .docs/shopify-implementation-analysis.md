# Shopify Integration - Implementation Analysis

## Overview
This document identifies conflicts between the requirements document and the current application state, plus key questions and decisions needed before implementation.

---

## 🔴 CRITICAL CONFLICTS & DECISIONS

### 1. Database: SQLite vs PostgreSQL

**Requirements say:** PostgreSQL with JSONB fields, GIN indexes, full-text search
**Current state:** SQLite in all environments (dev, test, prod)

**Decision needed:**
- **Option A (Recommended):** Migrate to PostgreSQL now
  - Required for JSONB fields (contacts.addresses, orders.line_items, products.variants)
  - Required for GIN indexes on arrays/JSONB
  - Required for array fields (tags)
  - Required for full-text search (tsvector)
  - Better for production at scale
  
- **Option B:** Stay with SQLite temporarily
  - Use `serialize :field, coder: JSON` for JSON fields (like you're doing now)
  - Use string fields instead of arrays, parse as needed
  - No GIN indexes (performance hit on large datasets)
  - Migrate to PostgreSQL later (more painful migration)

**My Recommendation:** Migrate to PostgreSQL NOW before adding Shopify integration. The data structures in the requirements document depend on PostgreSQL features. Migrating later with real Shopify data will be much harder.

---

### 2. Contact Model: New vs Existing CampaignContact

**Requirements say:** Create new `Contact` model as central customer/contact entity
**Current state:** `CampaignContact` model that belongs to Campaign (campaign-specific recipients)

**The Distinction:**
- **Contact** = A person in your database (from Shopify, CSV, etc.) - reusable across campaigns
- **CampaignContact** = A specific person receiving a specific campaign (with mailing status, Lob tracking, etc.)

**Decision:**
We need BOTH models with this relationship:
```
Contact (customer from Shopify)
  ├─ many CampaignContacts (each campaign send)
  └─ many Orders
  
CampaignContact (existing, enhance it)
  ├─ belongs_to :campaign
  └─ belongs_to :contact (NEW)
```

**Implementation:**
1. Create new `Contact` model per requirements spec
2. Keep `CampaignContact` as-is (it's the "send record")
3. Add `contact_id` foreign key to `CampaignContact` (nullable for backward compatibility)
4. When user creates campaign, they select from Contacts → creates CampaignContacts
5. CampaignContact syncs address/name from Contact unless manually overridden

---

### 3. Background Jobs: Solid Queue vs Sidekiq

**Requirements say:** Sidekiq for background jobs with `sidekiq-cron` for scheduling
**Current state:** Solid Queue (Rails 8 default) with recurring.yml for scheduled jobs

**Decision:**
- **Option A (Recommended):** Stick with Solid Queue
  - Already configured and working
  - Rails 8 native, zero dependencies
  - Recurring jobs work via recurring.yml
  - SQLite or PostgreSQL backed
  - No Redis required
  
- **Option B:** Switch to Sidekiq
  - More features (unique jobs, job scheduling)
  - Better monitoring UI
  - Requires Redis
  - More operational complexity

**My Recommendation:** Stay with Solid Queue. It's sufficient for the Shopify integration needs. The requirements document was written before Rails 8 made Solid Queue the default.

**Changes to requirements:**
- Replace `ShopifyFullSyncJob.perform_later` → stays the same (Active Job interface)
- Replace `sidekiq-cron` config → use `config/recurring.yml`
- Replace `sidekiq_jid` field → use `job_id` (Active Job ID)
- Monitoring: use Mission Control Jobs (Rails 8's built-in job dashboard)

---

### 4. Shopify Gems: shopify_app vs Manual OAuth

**Requirements say:** Use `shopify_app` gem (Rails engine with OAuth + webhooks)
**Current state:** No Shopify gems installed

**Decision:**
- **Option A:** Use `shopify_app` gem (easier)
  - Handles OAuth flow automatically
  - Handles webhook registration and verification
  - More "magic," less control
  - Good for simple integrations
  
- **Option B:** Use `shopify_api` gem + manual OAuth (more control)
  - Build OAuth flow manually (more work)
  - Full control over webhook handling
  - Better for custom needs
  - Recommended by modern Shopify docs

**My Recommendation:** Use `shopify_api` gem ONLY, build OAuth manually. The `shopify_app` gem is somewhat dated and overly complex for your needs. We'll build the OAuth flow following current best practices.

---

## 🟡 IMPORTANT QUESTIONS TO ANSWER

### 5. Multi-Store Data Strategy

**Question:** When an Advertiser connects multiple Shopify stores, how should duplicate customers be handled?

**Scenario:**
- Store A (US): customer@example.com - Jane Doe - $500 spent
- Store B (EU): customer@example.com - Jane Doe - $300 spent

**Options:**
a) **Keep separate** (recommended for MVP)
   - Two Contact records
   - source_id distinguishes them
   - Simpler to implement
   - Each store's data stays isolated
   - Segments can filter by store if needed

b) **Merge by email**
   - One Contact record with combined data
   - Complex: which address is primary? How to aggregate total_spent?
   - Requires contact merging logic
   - Better UX but much more complex

**My Recommendation:** Keep separate for MVP. Add "merge contacts" feature in Phase 2 if customers request it.

---

### 6. Campaign Building Workflow

**Question:** How do users create campaigns with Shopify contacts?

**Current flow:** User manually uploads CSV → creates CampaignContacts
**New flow with Shopify:** ???

**Options:**

**Option A: Contact Selection (modern, recommended)**
1. User goes to Campaigns → New Campaign
2. Select contacts using segment builder:
   - "All customers from Store A"
   - "Customers who spent > $500"
   - "Customers who bought Product X"
3. System creates CampaignContacts from selected Contacts
4. User designs postcard and sends

**Option B: Keep current CSV flow, add Shopify export**
1. User exports Shopify contacts to CSV
2. User uploads CSV (existing flow)
3. Less integrated, more manual

**My Recommendation:** Option A, but this requires building a segment builder (not in this Shopify spec). For MVP, could do a simpler "Select All Contacts from Store" option.

---

### 7. Historical Order Data Access

**Question:** Should we implement the "request historical access" flow or start with full access?

**Context:** Shopify limits first API call to last 60 days of orders unless you apply for extended access.

**Options:**
a) **Start with 60-day limit** (per requirements)
   - Sync last 60 days initially
   - Show UI prompt to request historical access
   - Manual process: user must apply to Shopify
   - After approval, backfill historical orders

b) **Apply for extended access upfront**
   - Include in OAuth scope request
   - Get full access from the start
   - Simpler UX, no manual step
   - May require app approval by Shopify

**My Recommendation:** Start with 60-day limit. It's faster to get approved and you can add historical access as Phase 2.

---

### 8. Product Data Usage

**Question:** What will you actually DO with product data?

**Current app:** Sends postcards to contacts. No product features yet.

**Potential uses:**
- "Buy Product X" personalized postcards (requires template merging)
- Segment: "Customers who bought Product X"
- Product recommendation engine
- Abandoned cart campaigns

**Decision Impact:**
- If no immediate product use → skip product sync for MVP (save complexity)
- If yes → need to define exactly what features require products

**My Recommendation:** Sync products in MVP (it's straightforward), but defer product-based segmentation/campaigns to Phase 2.

---

### 9. Webhook vs Scheduled Sync as Primary

**Question:** What's the "source of truth" strategy?

**Options:**
a) **Webhooks primary, scheduled sync as backup** (requirements doc approach)
   - Real-time updates
   - Scheduled sync catches missed webhooks
   - More complex (two code paths)

b) **Scheduled sync primary, webhooks as optimization**
   - Scheduled sync is source of truth
   - Webhooks update immediately for UX
   - Sync reconciles any differences
   - Simpler to reason about

**My Recommendation:** Option B for MVP. Get scheduled syncing working perfectly first, add webhooks as Phase 2 optimization.

---

### 10. Contact Permissions and Privacy

**Question:** Should all Advertiser members see all contacts, or role-based visibility?

**Current state:** Role-based advertiser memberships (owner, admin, editor, viewer)
**Contact data:** May include PII (email, phone, addresses, purchase history)

**Options:**
a) **All members see all contacts** (simpler)
   - Viewer role can see contact data
   - Simpler to implement
   - May have privacy concerns

b) **Role-based visibility**
   - Viewers can't see contact details
   - Only owners/admins see PII
   - More complex queries (scope by role)

**My Recommendation:** Option A for MVP. All Advertiser members see all data. Add role restrictions in Phase 2 if needed for compliance.

---

## 🟢 IMPLEMENTATION PLAN ADJUSTMENTS

### Phase 1: Database Migration (2-3 days)
**Do this FIRST before any Shopify code**

1. Add `pg` gem, remove/keep `sqlite3` as fallback
2. Update `config/database.yml` for PostgreSQL
3. Set up PostgreSQL locally (Postgres.app or Homebrew)
4. Export SQLite data (if you have real data)
5. Re-run migrations on PostgreSQL
6. Update serialized fields to use `jsonb` columns
7. Test existing features work on PostgreSQL

**Why first:** The Shopify models need PostgreSQL features (JSONB, arrays, GIN indexes)

---

### Phase 2: Core Data Models (3-4 days)

1. **Create Contact model** (per spec)
   - Full schema from requirements doc
   - Polymorphic source (ShopifyStore, ManualUpload, etc.)
   - Validations and indices

2. **Create Order model** (per spec)
   - JSONB line_items
   - Polymorphic source
   - Link to Contact

3. **Create Product model** (per spec)
   - JSONB variants, images
   - Polymorphic source

4. **Create ShopifyStore model** (per spec)
   - Encrypted access_token
   - Connection metadata

5. **Create SyncJob model** (per spec)
   - Track sync progress
   - Error handling

6. **Update CampaignContact**
   - Add `contact_id` foreign key (nullable)
   - Add methods to sync from Contact
   - Backward compatible with existing campaigns

---

### Phase 3: Shopify OAuth Connection (3-4 days)

1. Add `shopify_api` gem
2. Configure Shopify app credentials (env vars)
3. Create routes for OAuth flow
4. Create `Integrations::ShopifyController`
   - GET /advertisers/:slug/integrations/shopify
   - GET /advertisers/:slug/integrations/shopify/connect
   - GET /auth/shopify/callback
   - POST /advertisers/:slug/integrations/shopify/disconnect
5. Build OAuth flow (store session, exchange code for token)
6. Create ShopifyStore record on successful auth
7. Build integration page UI

---

### Phase 4: Initial Sync Job (4-5 days)

1. Create `ShopifyFullSyncJob` (Active Job)
2. Build Shopify API client wrapper (`Services::ShopifyClient`)
3. Implement customer sync logic
   - Fetch from Shopify API (paginated)
   - Map Shopify fields → Contact fields
   - Upsert (find or create + update)
   - Handle errors per-record
4. Implement order sync logic
   - 60-day limitation
   - Link to Contact by email
   - JSONB line_items
5. Implement product sync logic
   - Variants as JSONB
   - Images array
6. Update SyncJob record with progress
7. Error handling and retry logic
8. Rate limit handling (429 responses)

---

### Phase 5: Incremental Sync (2-3 days)

1. Create `ShopifyIncrementalSyncJob`
2. Fetch only records updated since `last_sync_at`
3. Same upsert logic as full sync
4. Much faster
5. Set up recurring job in `config/recurring.yml`
   - Hourly by default
   - Configurable per store

---

### Phase 6: UI & Observability (3-4 days)

1. Build integrations index page
2. Build Shopify integration page
   - Show connected stores
   - Sync status and history
   - Settings dropdown
3. Sync history UI (list SyncJobs)
4. Sync detail modal
5. "Sync Now" button
6. Disconnect confirmation modal
7. Disconnected store banner (app-wide)
8. Email notifications via Loops
   - Sync complete
   - Sync failed
   - Store disconnected

---

### Phase 7: Webhooks (3-4 days) - OPTIONAL FOR MVP

1. Install webhooks on OAuth connection
2. Create webhook routes
3. Create `Webhooks::ShopifyController`
4. Verify HMAC signatures
5. Create `ShopifyWebhookJob`
6. Handle each webhook topic
   - customers/create, customers/update
   - orders/create, orders/updated
   - products/create, products/update
   - app/uninstalled
7. Idempotency handling
8. Error handling

---

### Phase 8: Polish & Testing (2-3 days)

1. Error scenarios testing
2. Rate limit handling testing
3. Large store testing (10K+ customers)
4. Multi-store testing
5. Documentation
6. Deploy to production

---

## 📊 REVISED TIMELINE

**With PostgreSQL migration:**
- Week 1 (Days 1-5): PostgreSQL migration + Core data models
- Week 2 (Days 1-5): Shopify OAuth + Initial Sync Job
- Week 3 (Days 1-5): Incremental Sync + UI & Observability
- Week 4 (Days 1-3): Webhooks (optional) + Polish & Testing

**Total: 3-4 weeks to MVP**

**MVP Definition (without webhooks):**
- ✅ Connect Shopify store via OAuth
- ✅ Initial full sync (customers, orders, products)
- ✅ Incremental scheduled syncs (hourly)
- ✅ Sync status and history UI
- ✅ Multi-store support
- ✅ Error handling and retry
- ✅ Email notifications
- ❌ Webhooks (Phase 2)
- ❌ Segment builder (separate project)
- ❌ Product-based campaigns (Phase 2)

---

## 🎯 IMMEDIATE NEXT STEPS

### Before writing any Shopify code:

1. **Decision on Database**
   - Confirm: Migrate to PostgreSQL now? (recommended)
   - Or: Adapt requirements to work with SQLite? (not recommended)

2. **Decision on Contact/CampaignContact Split**
   - Confirm: Create new Contact model + enhance CampaignContact?
   - This affects how campaigns work

3. **Decision on Webhooks in MVP**
   - Skip for MVP? (my recommendation)
   - Or include? (adds 1 week)

4. **Decision on Segment Builder**
   - Is this part of Shopify integration?
   - Or separate project after Shopify data is syncing?

5. **Set up Shopify Partner Account**
   - Create Shopify Partner account
   - Create development store for testing
   - Create Shopify app (get API key and secret)

---

## 📝 QUESTIONS FOR YOU

1. **Do you have real production data in SQLite that needs migrating?** Or is this still early enough to just switch to PostgreSQL?

2. **How do you envision users creating campaigns from Shopify contacts?** Manual selection? Segment builder? Export to CSV?

3. **Are there any Shopify-specific features you want beyond what's in the requirements?** (e.g., discount codes, abandoned cart, specific product recommendations)

4. **What's your priority: Ship fast with fewer features, or build complete system per requirements?**

5. **Do you have a Shopify Partner account and test store already?** If not, we need to create those first.

6. **Is there any existing customer/production usage of the app that would be affected by database migration?**

---

## 🔧 TECHNICAL NOTES

### Rails 8 / Modern Rails Considerations

The requirements doc was written before Rails 8. Here are modern equivalents:

| Requirements Doc | Rails 8 Modern Approach |
|-----------------|------------------------|
| Sidekiq + sidekiq-cron | Solid Queue + recurring.yml |
| `sidekiq_jid` | `job_id` (Active Job ID) |
| Sidekiq Web UI | Mission Control Jobs |
| Redis (for Sidekiq) | Not needed (Solid Queue uses DB) |
| Manual webhook verification | Built into controller with `verify_authenticity_token` + HMAC check |

### Security Considerations

1. **Access token encryption:** Use Rails 7+ built-in `encrypts` attribute
2. **Webhook verification:** HMAC signature validation on every webhook
3. **GDPR compliance:** Implement `customers/redact` webhook handler
4. **Rate limiting:** Already have `rack-attack` gem installed

### Performance Considerations

1. **Batch processing:** Use `upsert_all` for bulk contact/order imports
2. **Pagination:** Shopify API returns max 250 records per request
3. **Job queuing:** Use separate queue for Shopify syncs: `queue_as :shopify_sync`
4. **Database indices:** Critical for querying large contact/order datasets

---

## ✅ READY TO START?

Once you answer the questions above, I can:
1. Start with PostgreSQL migration (if confirmed)
2. Create all the models with correct schema
3. Build the OAuth flow
4. Implement the sync jobs
5. Build the UI

Let me know which decisions you want to make, and we'll proceed!

