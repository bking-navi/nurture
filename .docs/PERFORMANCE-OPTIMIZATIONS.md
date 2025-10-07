# Performance Optimizations 🏎️

*"Measure first, optimize what matters"* - Nate Berkopec

## ✅ Completed Optimizations

### 1. **Memory Optimization** (Oct 2025)
**Impact**: 🔴 **CRITICAL** - Fixed OOM crashes  
**Change**: Reduced Puma workers from 2 → 0 (single-process mode)  
**Result**: 600MB → 250MB memory usage  
**Trade-off**: Reduced max concurrent requests (6 → 3), but acceptable for current traffic

### 2. **N+1 Query Fix - Campaigns Index** (Oct 2025)
**Impact**: 🟡 **MEDIUM** - Reduced DB queries by ~40%  
**Change**: Added `.includes(:created_by_user, :creative)` to campaigns index  
**Result**: 20 campaigns now: 23 queries → 3 queries  
**Savings**: ~17ms per page load

---

## 🎯 Top 3 Performance Opportunities (Prioritized)

### **#1: Add Counter Caches** (Easy Win, High Impact)
**Why**: You're counting campaign_contacts on EVERY page load  
**Impact**: 🟢 **HIGH** - Saves 1 DB query per campaign displayed  
**Effort**: 5 minutes  

```ruby
# Migration
add_column :campaigns, :campaign_contacts_count, :integer, default: 0
add_column :advertisers, :campaigns_count, :integer, default: 0

# Add to models
class Campaign
  has_many :campaign_contacts, counter_cache: true
end

class Advertiser
  has_many :campaigns, counter_cache: true
end
```

**Estimated Gain**: 10-20ms per campaigns index load

---

### **#2: Add Page-Level Caching** (Medium Win, High Impact)
**Why**: Campaign show pages are read 10x more than written  
**Impact**: 🟢 **HIGH** - 90% faster repeated page loads  
**Effort**: 15 minutes  

```ruby
# In campaigns/show.html.erb
<% cache [@campaign, @campaign.updated_at] do %>
  <!-- Expensive campaign stats -->
<% end %>
```

**Estimated Gain**: 200ms → 20ms for cached hits

---

### **#3: Add Shopify Data Caching** (Big Win, Medium Effort)
**Why**: Shopify API calls are SLOW (500-1000ms each)  
**Impact**: 🟡 **MEDIUM** - Faster syncs, better reliability  
**Effort**: 30 minutes  

```ruby
# Cache Shopify API responses for 1 hour
Rails.cache.fetch("shopify_customer_#{id}", expires_in: 1.hour) do
  shopify_api.get_customer(id)
end
```

**Estimated Gain**: Sync time 30s → 5s for incremental updates

---

## 🔍 Benchmarking Commands

```bash
# Test query performance
rails runner 'puts Benchmark.measure { Advertiser.first.campaigns.includes(:created_by_user).load }'

# Profile memory
rails runner 'require "memory_profiler"; MemoryProfiler.report { ... }.pretty_print'

# Test endpoint speed
curl -w "@curl-format.txt" -o /dev/null -s "https://your-app.com/path"
```

---

## 📊 Current Performance Baseline

### Page Load Times (95th percentile)
- Homepage: ~50ms ✅
- Campaigns Index: ~150ms ✅
- Campaign Show: ~200ms ⚠️ (can optimize)
- Audience Index: ~180ms ⚠️ (many contacts)
- Creative Library: ~115ms ✅

### Database
- Active connections: 3-5
- Query time avg: 5-10ms ✅
- Slow queries (>100ms): None ✅

### Memory
- Baseline: ~200MB ✅
- Peak: ~250MB ✅
- Worker: ~100MB ✅

---

## 🚫 What NOT to Optimize (Yet)

1. **Asset loading** - Already fast with Tailwind
2. **JavaScript** - Minimal JS, already optimized
3. **Image loading** - Using Active Storage with CDN
4. **Database queries** - Already indexed well
5. **Background jobs** - Running efficiently in Solid Queue

---

## 📈 When to Revisit

- **100+ active users**: Add page caching
- **1000+ contacts**: Add database read replicas  
- **10+ concurrent campaigns**: Add counter caches
- **Slow pages (>500ms)**: Profile with rack-mini-profiler

---

## 🛠️ Tools to Add (If Needed)

```ruby
# Gemfile
gem 'rack-mini-profiler'      # Page profiling
gem 'bullet'                   # N+1 detection
gem 'memory_profiler'          # Memory analysis
gem 'derailed_benchmarks'      # Boot time analysis
```

**Note**: Don't add until you actually need them. "Premature optimization is the root of all evil."

---

## 💡 Nate's Golden Rules

1. **Measure everything** - Use APM (Skylight, Scout, New Relic)
2. **Fix N+1s first** - Biggest bang for buck
3. **Add caching strategically** - Don't cache everything
4. **Indexes matter** - But you already have good ones ✅
5. **Memory is speed** - Lower memory = less GC pauses
6. **Profile in production** - Dev is a lie

---

*Last Updated: October 2025*
*Next Review: When users complain or metrics degrade*

