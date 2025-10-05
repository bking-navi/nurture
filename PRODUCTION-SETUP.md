# Production Setup Guide

This guide covers everything you need to configure when deploying the Nurture app with Lob postcard integration to production.

## 1. Lob.com Setup

### Create Your Lob Account
1. Go to [https://dashboard.lob.com/signup](https://dashboard.lob.com/signup)
2. Complete account registration
3. Verify your email address

### Get Your API Keys

#### Test API Key (for staging/development)
1. Log in to [Lob Dashboard](https://dashboard.lob.com)
2. Navigate to **Settings** → **API Keys**
3. Copy your **Test Secret Key** (starts with `test_`)
   - Use this for development and staging environments
   - Test mode won't actually print/mail postcards
   - No charges apply to test sends

#### Live API Key (for production)
1. In Lob Dashboard, go to **Settings** → **API Keys**
2. Copy your **Live Secret Key** (starts with `live_`)
   - ⚠️ **WARNING**: Live mode will actually print and mail postcards
   - You will be charged for live sends
3. Before going live, you must:
   - Add a payment method in Lob Dashboard
   - Verify your business identity (required by USPS)
   - Review Lob's pricing at [https://www.lob.com/pricing](https://www.lob.com/pricing)

### Configure API Keys in Rails

#### Option A: Using Rails Credentials (Recommended)
```bash
# Edit your production credentials
EDITOR=nano rails credentials:edit --environment production

# Add these keys:
lob:
  live_api_key: live_YOUR_LIVE_KEY_HERE
  test_api_key: test_YOUR_TEST_KEY_HERE
```

#### Option B: Using Environment Variables
Set these in your hosting environment (Heroku, Render, Railway, etc.):
```
LOB_API_KEY=live_YOUR_LIVE_KEY_HERE        # Production
LOB_TEST_API_KEY=test_YOUR_TEST_KEY_HERE  # Development/Staging
```

### Verify Lob Configuration
After deploying, check your Rails logs on startup:
```
✓ Lob configured with LIVE API key (live_xxxxxxxxxxxx...)
```

If you see a warning, your API key is not configured correctly.

## 2. Loops.so Email Setup

### Create Your Loops Account
1. Go to [https://loops.so](https://loops.so)
2. Sign up and verify your email
3. Complete onboarding

### Get Your API Key
1. In Loops dashboard, go to **Settings** → **API**
2. Copy your **API Key**
3. Add to Rails credentials:

```bash
EDITOR=nano rails credentials:edit --environment production

# Add:
loops:
  api_key: YOUR_LOOPS_API_KEY_HERE
```

Or as environment variable:
```
LOOPS_API_KEY=YOUR_LOOPS_API_KEY_HERE
```

### Create Email Templates

You need to create these two transactional email templates in Loops:

#### Template 1: Campaign Sent
**Template ID**: `campaign_sent`

**Subject**: Campaign "{{campaign_name}}" sent successfully

**Body**:
```
Hi there,

Great news! Your postcard campaign "{{campaign_name}}" has been sent.

📊 Campaign Summary:
- Postcards sent: {{postcards_sent}}
- Failed sends: {{postcards_failed}}
- Total cost: {{total_cost}}

View your campaign:
{{campaign_url}}

Thanks for using Nurture!
```

**Variables**:
- `campaign_name` (string)
- `postcards_sent` (number)
- `postcards_failed` (number)
- `total_cost` (string) - formatted currency
- `campaign_url` (string)

#### Template 2: Campaign Failed
**Template ID**: `campaign_failed`

**Subject**: Campaign "{{campaign_name}}" failed to send

**Body**:
```
Hi there,

Unfortunately, your postcard campaign "{{campaign_name}}" encountered an error and could not be sent.

❌ Error Details:
{{error_message}}

What to do next:
1. Review your campaign settings
2. Check that all recipient addresses are valid
3. Try sending again

View your campaign:
{{campaign_url}}

Need help? Contact our support team:
{{support_url}}
```

**Variables**:
- `campaign_name` (string)
- `error_message` (string)
- `campaign_url` (string)
- `support_url` (string)

### Create Templates in Loops
1. In Loops dashboard, go to **Transactional** → **Create Template**
2. Set the Template ID to exactly match above (e.g., `campaign_sent`)
3. Configure the subject line and body
4. Add all required variables
5. Click **Publish**
6. Repeat for the second template

### Test Email Delivery
After deploying, send a test campaign with a single postcard to verify:
1. Campaign completion email is sent
2. All variables populate correctly
3. Links work properly

## 3. Environment-Specific Configuration

### Development
```bash
# .env or credentials
LOB_TEST_API_KEY=test_...
LOOPS_API_KEY=...
```
- Uses Lob test mode (no actual mailing)
- Emails go to development addresses

### Staging
```bash
LOB_TEST_API_KEY=test_...
LOOPS_API_KEY=...
```
- Uses Lob test mode (no actual mailing)
- Can test full flow without charges

### Production
```bash
LOB_API_KEY=live_...
LOOPS_API_KEY=...
```
- Uses Lob live mode (ACTUALLY MAILS POSTCARDS)
- Charges your Lob account
- Sends real emails to users

## 4. Database Migrations

Make sure all migrations are run:
```bash
rails db:migrate
```

Key migrations for campaigns:
- `CreateCampaigns` - Creates campaigns table
- `CreateCampaignContacts` - Creates campaign_contacts table

## 5. Background Job Processing

This app uses Rails 8's built-in `solid_queue` for background jobs.

### Verify Background Job Configuration
In `config/environments/production.rb`:
```ruby
config.active_job.queue_adapter = :solid_queue
```

### Start Background Workers
If using a separate worker process (recommended for production):
```bash
bundle exec rails solid_queue:start
```

Or in Procfile:
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec rails solid_queue:start
```

### Monitor Jobs
Check the `solid_queue_*` tables in your database to monitor job processing.

## 6. Testing Your Setup

### Test in Development First
1. Create a test campaign
2. Add your own address as recipient
3. Send the campaign
4. Check:
   - Postcard appears in Lob test dashboard
   - You receive completion email
   - Campaign status updates correctly

### Test in Production (Carefully!)
1. Start with a single test postcard to yourself
2. Use a real address you can verify
3. Monitor the first send closely
4. Verify charges in Lob dashboard
5. Wait for physical delivery (7-10 days)

## 7. Costs and Billing

### Lob Pricing (as of 2024)
- 6x9" postcards: ~$0.61-$1.05 each (depending on volume)
- First Class Mail: included
- Address verification: Free

### Monitor Your Spending
1. Set up billing alerts in Lob dashboard
2. Review `actual_cost_cents` in campaigns table
3. Implement spending limits if needed (post-MVP)

## 8. Session Storage (Important!)

### Cookie Overflow Issue
The app stores only essential Lob response data (ID, URL, dates) to avoid session cookie overflow. The full Lob response can be 6KB+ which exceeds cookie limits.

**If you still encounter cookie overflow errors:**

1. **Option A: Switch to Database Sessions** (Recommended for production)
   ```ruby
   # config/initializers/session_store.rb
   Rails.application.config.session_store :active_record_store, key: '_nurture_session'
   ```
   
   Then run:
   ```bash
   rails generate active_record:session_migration
   rails db:migrate
   ```

2. **Option B: Use Redis Sessions** (Best for high-traffic apps)
   ```ruby
   # Add to Gemfile
   gem 'redis-session-store'
   
   # config/initializers/session_store.rb
   Rails.application.config.session_store :redis_session_store, {
     key: '_nurture_session',
     redis: {
       url: ENV['REDIS_URL'] || 'redis://localhost:6379/0',
       expire_after: 1.week
     }
   }
   ```

## 9. Troubleshooting

### Lob API Errors
**401 Unauthorized**
- Check that API key is configured correctly
- Verify key starts with `live_` or `test_`

**422 Validation Error**
- Check advertiser address is valid (especially state field)
- Verify recipient addresses are properly formatted

### Cookie Overflow Error
**ActionDispatch::Cookies::CookieOverflow**
- This has been fixed by storing only essential Lob data
- If you still see this, switch to database or Redis sessions (see section 8)
- Clear your browser cookies and try again

### Email Not Sending
**Template Not Found**
- Verify template IDs match exactly: `campaign_sent`, `campaign_failed`
- Check templates are published in Loops

### Background Jobs Not Processing
- Verify `solid_queue` is running
- Check logs for job errors
- Review `solid_queue_failed_executions` table

## 10. Security Checklist

- [ ] API keys are stored in credentials or secure env vars (not in code)
- [ ] Production uses separate API keys from development
- [ ] Database credentials are secure
- [ ] SSL/HTTPS is enabled
- [ ] Rate limiting is configured (if needed)
- [ ] User permissions are properly enforced

## 11. Go-Live Checklist

Before sending your first production campaign:

- [ ] Lob account verified and payment method added
- [ ] Live API key configured in production
- [ ] Loops templates created and published
- [ ] Test campaign sent successfully in staging
- [ ] Background workers are running
- [ ] Monitored test send in production (to yourself)
- [ ] Reviewed Lob pricing and budgeting
- [ ] Confirmed advertiser address is valid
- [ ] Team is trained on campaign creation flow
- [ ] Support email/process is set up

## 12. Ongoing Maintenance

### Monitor These Metrics
- Campaign success/failure rates
- Average cost per postcard
- Delivery times
- Failed send reasons

### Regular Tasks
- Review failed campaigns and retry if needed
- Update Lob templates as needed
- Monitor API usage and costs
- Keep gems updated (`bundle update lob`)

## Need Help?

- **Lob Support**: [https://support.lob.com](https://support.lob.com)
- **Lob API Docs**: [https://docs.lob.com](https://docs.lob.com)
- **Loops Support**: [https://loops.so/docs](https://loops.so/docs)
- **Internal**: Check `.docs/` folder for more documentation

---

**Last Updated**: October 2025

