# ACH (Bank Account) Payments Implementation Plan

**Date**: October 7, 2025  
**Goal**: Add ACH/bank transfer option for lower-fee deposits

---

## 💡 Why ACH?

**Stripe Fees Comparison:**
- **Credit Card**: 2.9% + $0.30 per transaction
- **ACH**: 0.8% (capped at $5 per transaction)

**Example ($1,000 deposit):**
- Credit Card: $1,000 + $29.30 = **$1,029.30** charged to customer
- ACH: $1,000 + $5.00 = **$1,005.00** charged to customer ✅ **Saves $24.30!**

---

## 🏗️ Implementation Steps

### 1. Database Updates
No new migrations needed! We'll use existing transaction structure:
- `balance_transactions.status` (add column for pending/cleared)
- `balance_transactions.payment_method_type` (card vs us_bank_account)

### 2. Update StripePaymentService
- Add `charge_with_bank_account()` method
- Handle ACH-specific flow (requires verification)
- Add status tracking (pending → succeeded)

### 3. Update UI
**Add Funds Page:**
- Add payment method selector (Card or Bank Account)
- Show fee comparison
- Add Bank Account form (Stripe Payment Element supports both!)
- Show "Processing time: 1-4 business days" for ACH

**Transaction History:**
- Show payment method type (Card/Bank)
- Show status (Pending/Cleared) for ACH
- Highlight savings from ACH

### 4. Webhooks
Add handlers for ACH-specific events:
- `payment_intent.processing` - ACH initiated
- `payment_intent.succeeded` - ACH cleared (add funds now)
- `payment_intent.payment_failed` - ACH failed (notify customer)

### 5. Email Notifications
**New emails:**
- ACH payment initiated (funds pending)
- ACH payment cleared (funds added)
- ACH payment failed

---

## 🔄 User Flow

### Credit Card (Current):
1. Customer enters card → Stripe processes → Funds added immediately ✅

### ACH (New):
1. Customer enters bank account → Stripe initiates ACH
2. Email: "ACH payment initiated, funds pending (1-4 days)"
3. 1-4 days later: Stripe sends webhook → Funds added
4. Email: "ACH payment cleared! $X added to balance"

---

## 📊 Recommended Minimums

- **Credit Card**: $5 minimum (current)
- **ACH**: $100 minimum (to make the wait worthwhile)
- **ACH**: $10,000 maximum per transaction (Stripe limit)

---

## 🎯 Benefits

1. **Lower costs** for large deposits
2. **Better for recurring** customers who top up $500+
3. **Encourages larger** deposits (better unit economics)
4. **Professional** - shows we're a serious platform

---

## ⚠️ Considerations

1. **Failed ACH** - Can fail up to 4 days later (insufficient funds)
2. **Refunds** - ACH refunds also take 5-7 days
3. **Disputes** - ACH has 60-day dispute window (vs 120 for cards)
4. **Instant verification** - Plaid integration can verify instantly (Stripe supports this)

---

## 🚀 Launch Strategy

**Phase 1**: Add ACH option to add funds page
**Phase 2**: Show fee savings to encourage ACH for $500+
**Phase 3**: Add instant verification via Plaid (optional)

Ready to build? 🎉

