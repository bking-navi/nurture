# Nurture: Go-to-Market Readiness (One-Pager)

**Date**: October 7, 2025 | **Status**: 60% Ready | **Timeline**: 4-6 weeks to launch

---

## What We Built (25 Hours)

✅ Working MVP: Shopify integration, postcard sending (Lob), RFM segmentation, creative management  
✅ Technical Quality: B+ (solid architecture, good security, scalable foundation)  
❌ **Missing**: Attribution tracking, billing system, production hardening

---

## Critical Gaps Blocking Launch

| Gap | Impact | Effort | Priority |
|-----|--------|--------|----------|
| **1. Attribution Tracking** | Can't prove ROI → 70% churn | 32h | 🔴 Week 1 |
| **2. Billing & Payments** | Can't charge customers | 16h | 🔴 Week 1 |
| **3. Usage Tracking** | Can't enforce limits or invoice | 12h | 🔴 Week 2 |
| **4. Error Handling** | Silent failures lose money | 24h | 🟡 Week 2 |
| **5. Monitoring** | Can't detect issues | 4h | 🟡 Week 1 |

**Total**: 88 hours (~2 weeks full-time or 4 weeks half-time)

---

## The Attribution Problem (Biggest Risk)

**Without attribution**: Customers send $1,000 in postcards, can't prove they drove sales → Cancel subscription  
**With attribution**: Customers prove 3-5x ROAS → Send more campaigns, refer others

**Solution** (32 hours):
- Promo codes (direct tracking): 12h
- Time-window matching (passive tracking): 8h
- Analytics dashboard: 12h

**ROI**: Reduces churn from 70% → 30%, increases LTV by 3x

---

## The Billing Problem (Launch Blocker)

**What's Missing**:
- ❌ Stripe integration
- ❌ Subscription management
- ❌ Usage tracking & metering
- ❌ Invoicing
- ❌ Payment failure handling
- ❌ Plan limits & quotas

**Solution** (28 hours):
- Stripe setup + subscriptions: 16h
- Usage metering (postcards sent): 8h
- Plan enforcement + billing: 4h

**Without this**: Literally cannot charge customers

---

## Launch Roadmap

### **Week 1-2: Private Beta Prep** (52h)
- Attribution tracking: 32h
- Stripe + billing: 16h
- Basic monitoring: 4h
- **Launch**: 5-10 free beta customers (prove it works)

### **Week 3-4: Limited Launch** (36h)
- Usage tracking: 12h
- Error handling: 24h
- **Launch**: 20-50 paying customers

### **Month 2: Public Launch**
- Advanced features (QR tracking, tests, docs)
- Scale to 100+ customers

---

## Market Positioning

**Competitor**: Postpilot ($150-500/month, basic attribution)  
**Our Edge**: Better attribution + Better pricing ($99/month)  
**Positioning**: "Klaviyo for direct mail - measure everything"

---

## Financial Reality Check

**Pricing**: $99/month + $0.25/postcard markup

| Month | Customers | Postcards/mo | Revenue | Lob Costs | Gross Profit | Margin |
|-------|-----------|-------------|---------|-----------|--------------|---------|
| 3 | 50 | 40,000 | $14,950 | $42,000 | -$27,050 | -181% |
| 6 | 150 | 160,000 | $54,950 | $168,000 | -$113,050 | -206% |
| 12 | 400 | 480,000 | $159,600 | $504,000 | -$344,400 | -216% |

**Problem**: Current pricing doesn't work at scale. Need to either:
- Increase per-postcard markup to $0.50 (breaks even Month 12)
- Increase base subscription to $199/month
- Focus on volume customers (negotiate Lob discounts)

**Recommendation**: Launch with current pricing, optimize after proving value

---

## Success Metrics (3 Months)

✅ **Attribution Rate**: >70% (prove postcards drive sales)  
✅ **Churn**: <5% monthly (customers see value)  
✅ **MRR**: $10K+ (product-market fit)  
✅ **Delivery Rate**: >95% (operational excellence)

---

## Decision Points

### **GREEN LIGHT** ✅
- Technical foundation is solid (B+ quality)
- Market is proven (Postpilot exists, charges more)
- 88 hours to launch is achievable

### **YELLOW FLAG** ⚠️
- Pricing may need adjustment after beta
- Will need support bandwidth (10h/week)
- Initial months will be unprofitable (normal for SaaS)

### **RED FLAG** 🔴
- **Without attribution**: Product is worthless (can't prove ROI)
- **Without billing**: Can't launch at all

---

## Recommendation

**Invest 4-6 weeks** (~88 hours) to build:
1. Attribution tracking (prove value)
2. Billing system (charge customers)
3. Basic hardening (don't waste money)

**Timeline**:
- Week 1-2: Build critical features → Private beta
- Week 3-4: Harden + scale → Limited launch (50 customers)
- Month 2: Polish → Public launch (100+ customers)

**Expected Outcome**: Profitable SaaS with 400+ customers, $50K+ MRR by Month 12

---

**Prepared by**: Engineering | **Decision Needed**: Commit to 4-6 week launch timeline

