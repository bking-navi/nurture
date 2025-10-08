# Deployment Checklist - Suppression & Webhooks

This document outlines the steps needed after deploying the suppression system and webhook features.

## Pre-Deployment

### 1. Environment Variables

Add to your production environment:

```bash
APP_URL=https://yourdomain.com
```

This is required for Shopify webhooks to work correctly.

## Deployment Steps

### 1. Deploy Code
```bash
git push production main
```

### 2. Run Migrations
```bash
rails db:migrate
```

### 3. Register Webhooks for Existing Stores

```bash
# Get store IDs
rails runner "ShopifyStore.all.each { |s| puts s.id }"

# Register webhooks for each store
rails "shopify:register_webhooks[STORE_ID]"

# Verify registration
rails "shopify:list_webhooks[STORE_ID]"
```

## Post-Deployment Verification

### 1. Check Webhooks
```bash
rails "shopify:list_webhooks[STORE_ID]"
```

### 2. Test Webhook
Create a test order in Shopify and check logs for webhook processing.

### 3. Verify Suppression Settings
Visit /advertisers/:slug/settings/suppression

### 4. Test Campaign Suppression
Create campaign, import contacts, verify suppressed contacts show correctly.

## Troubleshooting

### Webhooks Not Firing
1. Verify APP_URL is set
2. Check webhook registration
3. Re-register if needed

### Suppression Not Working
1. Verify migrations ran
2. Check last_order_at is updating
3. Verify settings configured

## Additional Resources

- Feature documentation: .docs/SUPPRESSION-SYSTEM-COMPLETE.md
- Webhook guide: .docs/webhooks.md
