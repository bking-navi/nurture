# Shopify Webhooks

This app uses Shopify webhooks to automatically sync customer and order data in real-time.

## How It Works

When you connect a Shopify store, the app automatically registers 4 webhooks:
- `orders/create` - New orders
- `orders/updated` - Order updates  
- `customers/create` - New customers
- `customers/update` - Customer updates

These webhooks ensure:
- ✅ `last_order_at` is updated immediately when customers place orders
- ✅ Contact data stays in sync automatically
- ✅ Suppression rules (recent order/mail) work accurately
- ✅ No need for manual "Sync Now" clicks

## Production Setup

Set your production URL in the environment:

```bash
APP_URL=https://yourdomain.com
```

Webhooks will be registered automatically when stores are connected.

## Development Setup

### Option 1: Use a Tunnel (Recommended for full testing)

Use **ngrok**, **localhost.run**, or similar:

```bash
# Using ngrok
ngrok http 3000

# Then set APP_URL in .env.development
APP_URL=https://abc123.ngrok.io
```

### Option 2: Skip Webhooks (Works fine without them)

Don't set `APP_URL` in development. The app will:
- ⚠️ Register placeholder webhooks (won't receive data)
- ✅ Still work perfectly with manual "Sync Now" buttons
- ✅ Test webhook processing with rake tasks (see below)

## Testing Without a Tunnel

You can simulate webhooks locally using rake tasks:

```bash
# List all Shopify stores
rails console
> ShopifyStore.all.each { |s| puts "#{s.id}: #{s.shop_domain}" }

# Simulate a customer webhook
rails shopify:simulate_webhook[customer,STORE_ID]

# Simulate an order webhook  
rails shopify:simulate_webhook[order,STORE_ID]

# List registered webhooks
rails shopify:list_webhooks[STORE_ID]

# Manually register webhooks (if you set up ngrok)
rails shopify:register_webhooks[STORE_ID]

# Unregister all webhooks
rails shopify:unregister_webhooks[STORE_ID]
```

## Webhook Endpoints

All webhooks hit: `/webhooks/shopify/:action`

The controller:
1. Verifies HMAC signature for security
2. Queues a background job to process the data
3. Returns 200 OK immediately

## Security

- All webhooks verify the `X-Shopify-Hmac-SHA256` header
- Invalid signatures are rejected with 401 Unauthorized
- Webhook secrets are stored per-store in the database

## Troubleshooting

**Webhooks not firing in development?**
- Ensure `APP_URL` is set to your ngrok/tunnel URL
- Check webhook registration: `rails shopify:list_webhooks[STORE_ID]`
- Test locally: `rails shopify:simulate_webhook[order,STORE_ID]`

**Production webhooks failing?**
- Check logs for HMAC verification errors
- Verify `APP_URL` is set correctly
- Re-register: disconnect and reconnect the store

## How Suppression Works With Webhooks

When an order webhook arrives:
1. `ShopifyWebhookProcessorJob` processes the order
2. Finds or creates the linked `Contact`
3. Updates `contact.last_order_at` automatically
4. Future campaigns check this timestamp for "Recent Order Suppression"

This means **suppression is always accurate** without manual syncs! 🎉

