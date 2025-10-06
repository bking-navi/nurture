# Critical Decisions Needed - Quick Reference

## 🔴 MUST DECIDE BEFORE STARTING

### 1. Database: PostgreSQL or SQLite?
**Impact:** EVERYTHING depends on this
```
PostgreSQL ✅ RECOMMENDED
- Required for JSONB (line_items, variants, addresses)
- Required for array fields (tags)
- Required for GIN indexes (fast tag/JSON queries)
- Required for full-text search
- Better for scale

SQLite ❌ NOT RECOMMENDED
- Would need to serialize everything
- No array fields (use comma-separated strings)
- Slower queries on complex data
- Will hit limits at scale
- Would need to migrate later anyway
```

**My strong recommendation:** Switch to PostgreSQL NOW (2-3 days work)

---

### 2. Contact vs CampaignContact Models
**Impact:** How the entire app works

```
RECOMMENDED APPROACH:

Contact (NEW)
├─ Synced from Shopify (or CSV, or other sources)
├─ customer@example.com, Jane Doe, $500 spent
├─ Lives in Advertiser's database
└─ Reusable across campaigns

CampaignContact (EXISTING - ENHANCE)
├─ Belongs to specific Campaign
├─ Belongs to Contact (NEW RELATIONSHIP)
├─ Tracks: Lob postcard ID, delivery status, costs
└─ One per campaign send

WORKFLOW:
1. Shopify syncs → creates/updates Contacts
2. User creates Campaign → selects Contacts → creates CampaignContacts
3. Campaign sends → updates CampaignContacts with tracking
```

**Question:** Agree with this approach?

---

### 3. Background Jobs: Solid Queue or Sidekiq?

```
Solid Queue ✅ RECOMMENDED (Current)
- Already configured
- Rails 8 native
- No Redis needed
- Recurring jobs via recurring.yml
- Sufficient for needs

Sidekiq ❌ NOT NEEDED
- Requires Redis
- More operational complexity
- Overkill for current needs
```

**My recommendation:** Stay with Solid Queue

---

### 4. Shopify Gems Strategy

```
shopify_api only ✅ RECOMMENDED
- Latest Shopify API
- Build OAuth manually (more control)
- Modern approach
- Clean implementation

shopify_app gem ❌ NOT RECOMMENDED
- Rails engine, lots of magic
- Somewhat dated
- Less control
- Overly complex
```

**My recommendation:** Use `shopify_api` gem, build OAuth ourselves

---

## 🟡 IMPORTANT DESIGN QUESTIONS

### 5. How do users create campaigns with Shopify contacts?

**Option A: Segment Builder** (more work, better UX)
- User selects "Customers who spent > $500"
- System creates CampaignContacts from matching Contacts
- Requires building segment/filter UI

**Option B: Simple Selection** (faster MVP)
- User selects "All contacts from Store A"
- Or: "All contacts with tag X"
- Simple dropdown/checkboxes
- Add advanced filtering later

**Option C: CSV Export/Import** (quick hack)
- User exports Contacts to CSV
- User imports CSV (existing flow)
- Not integrated

**Which do you prefer for MVP?**

---

### 6. Webhook Implementation Timing

**Option A: Skip webhooks in MVP** ✅ RECOMMENDED
- Get scheduled syncing working first
- Hourly incremental syncs (good enough for MVP)
- Add webhooks in Phase 2 for real-time updates
- Faster to market

**Option B: Include webhooks in MVP**
- Real-time updates
- More impressive demo
- More complex (adds 1 week)
- More can go wrong

**Which is more important: Speed to market or real-time sync?**

---

### 7. Multi-Store Strategy

**Scenario:** Customer exists in Store A (US) and Store B (EU)

**Option A: Keep Separate Contacts** ✅ RECOMMENDED FOR MVP
```
Contact #1: customer@example.com (from Store A)
Contact #2: customer@example.com (from Store B)
```
- Simpler
- Each store's data isolated
- Can still target both in campaigns

**Option B: Merge by Email**
```
Contact #1: customer@example.com (from both stores)
- total_spent: $800 (combined)
- Which address is primary?
- How to handle conflicting data?
```
- Better UX
- Much more complex
- Can add later if needed

**MVP: Keep separate, right?**

---

### 8. Shopify Product Usage

**Question:** What will you actually DO with product data?

Current features: Sending postcards to contacts (no product features yet)

**If you need products for:**
- ✅ "Buy Product X" personalized postcards → Sync products
- ✅ "Customers who bought Product X" segments → Sync products + complex queries
- ❌ Nothing yet → Skip products in MVP

**Do you have immediate product-based features planned?**

---

## 📋 PRE-WORK CHECKLIST

Before writing any code:

- [ ] **Confirm PostgreSQL migration** (or convince me why SQLite is fine)
- [ ] **Confirm Contact model architecture** (new model + enhance CampaignContact)
- [ ] **Decide on webhooks in MVP** (I recommend Phase 2)
- [ ] **Decide on campaign selection UX** (Simple for MVP? Or build segment builder?)
- [ ] **Set up Shopify Partner account** (need API credentials)
- [ ] **Create Shopify development store** (for testing)
- [ ] **Create Shopify app** in Partner dashboard (get API key/secret)

---

## 🎯 MY RECOMMENDATIONS FOR MVP

If you want to ship fast with high quality:

```
✅ INCLUDE IN MVP:
- PostgreSQL migration (prerequisite)
- Contact, Order, Product models
- ShopifyStore model with encrypted tokens
- OAuth connection flow
- Initial full sync job
- Incremental sync job (hourly recurring)
- SyncJob tracking/history
- Integration UI (status, history, settings)
- Multi-store support
- Email notifications (sync complete/failed)
- Manual "Sync Now" button
- Simple contact selection for campaigns ("All from Store X")

❌ DEFER TO PHASE 2:
- Webhooks (add later for real-time)
- Advanced segment builder (separate project)
- Product-based campaigns
- Historical order access beyond 60 days
- Contact merging across stores
- API usage analytics

⏱️ TIMELINE: 3 weeks to MVP
```

---

## 🚀 IMMEDIATE NEXT STEPS

**If you agree with recommendations above:**

1. I'll start PostgreSQL migration
2. Create all data models
3. Build OAuth flow
4. Implement sync jobs
5. Build UI

**If you have different preferences:**
Tell me which decisions you disagree with and we'll adjust!

---

## ❓ QUESTIONS TO ANSWER

Quick answers please:

1. **PostgreSQL migration - yes?** (I strongly recommend yes)
2. **Skip webhooks for MVP - yes?** (Add in Phase 2)
3. **How should campaigns select contacts?** (Simple dropdown for MVP?)
4. **Do you have Shopify Partner account?** (Need API credentials)
5. **Any real production data yet?** (Affects migration strategy)
6. **Want to start today?** 😄

Once you answer these, I'll start building immediately!

