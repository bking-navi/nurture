# 📮 Postcard Campaign Setup - Quick Start

## ✅ Pre-Launch Checklist

Complete these steps before sending your first campaign:

### 1. Lob.com Setup
- [ ] Sign up at https://dashboard.lob.com/signup
- [ ] Get your Test API key (Settings → API Keys)
- [ ] Get your Live API key (Settings → API Keys)
- [ ] Add keys to Rails credentials:

```bash
EDITOR="code --wait" rails credentials:edit

# Add these lines:
lob:
  test_api_key: test_YOUR_KEY_HERE
  live_api_key: live_YOUR_KEY_HERE
```

### 2. Loops.so Email Templates

Create these two templates in your Loops.so account:

#### Template: `campaign_sent`
**Subject:** `Your postcard campaign has been sent`

**Variables to add:**
- `campaign_name` (string)
- `postcards_sent` (number)
- `postcards_failed` (number)
- `total_cost` (string)
- `campaign_url` (string)

**Suggested content:**
```
Hi there,

Your campaign "{{campaign_name}}" has been sent!

Results:
• {{postcards_sent}} postcards sent
• {{postcards_failed}} failed to send  
• Total cost: {{total_cost}}

Expected delivery: 5-7 business days

[View Campaign]({{campaign_url}})
```

#### Template: `campaign_failed`
**Subject:** `Action needed: Campaign failed to send`

**Variables to add:**
- `campaign_name` (string)
- `error_message` (string)
- `campaign_url` (string)
- `support_url` (string)

**Suggested content:**
```
Hi there,

Your campaign "{{campaign_name}}" failed to send.

Error: {{error_message}}

Your account has not been charged. Please review and try again.

[View Campaign]({{campaign_url}}) | [Get Help]({{support_url}})
```

### 3. Test Your Setup

Run this in Rails console to verify configuration:

```ruby
# Test Lob configuration
ENV['LOB_API_KEY'].present?
# => true

# Test creating a verification
Lob::USVerification.verify(
  primary_line: "1234 Main St",
  city: "San Francisco", 
  state: "CA",
  zip_code: "94111"
)
# Should return address verification result

# Test Loops configuration  
loops = LoopsClient.new
# Should not raise error

# Check your advertiser state format
Advertiser.first.state
# Should be 2-letter code like "CA", not "California"
```

### 4. Fix Existing Data (if needed)

If you have advertisers with full state names instead of codes:

```ruby
# In rails console
Advertiser.where("LENGTH(state) > 2").find_each do |adv|
  puts "#{adv.name}: #{adv.state}"
  # Manually update or use a state abbreviation map
end
```

---

## 🚀 Send Your First Test Campaign

1. **Start your server:**
   ```bash
   bin/dev
   ```

2. **Navigate to campaigns:**
   - Go to your advertiser dashboard
   - Click "Campaigns" in navigation
   - Or visit: `/advertisers/YOUR_SLUG/campaigns`

3. **Create test campaign:**
   - Click "Create Campaign"
   - Name it "Test Campaign"
   - Click "Create Campaign"

4. **Add a test recipient:**
   - Click "Add Manually"
   - Use YOUR OWN ADDRESS (so you receive the postcard!)
   - Fill in all required fields
   - Click "Add Recipient"

5. **Select template:**
   - Click "Design" tab
   - Standard 6x9 template is pre-selected
   - Optionally add a custom message
   - Click "Save Changes"

6. **Review and send:**
   - Click "Review & Send" tab
   - Click "Calculate Cost"
   - Should show: "$1.05" for 1 postcard
   - Click "Send Campaign Now"
   - Confirm in the browser dialog

7. **Monitor progress:**
   - Campaign status changes to "Processing"
   - Background job sends to Lob (watch your logs)
   - You'll receive email when complete
   - Check campaign show page for status

8. **Verify success:**
   - Check your email for "campaign sent" notification
   - Visit campaign show page
   - Should see "Sent" status
   - Should see tracking information
   - Wait 5-7 business days for postcard delivery!

---

## 🐛 Troubleshooting

### "Lob API key not configured"
**Fix:** Add Lob API keys to Rails credentials (see step 1)

### Can't create campaign
**Check:**
- Logged in as Manager, Admin, or Owner?
- Advertiser exists and you're a member?

### CSV import fails
**Common issues:**
- Missing required columns: first_name, last_name, address_line1, city, state, zip
- State must be 2-letter code (CA, not California)
- ZIP must be 5 or 9 digits
- Invalid email format

**Fix:** Download sample CSV and match the format exactly

### Background job not running
**Check:**
- Solid Queue is configured
- No errors in `rails log`
- Job appears in queue: `SolidQueue::Job.count`

### Email not received
**Check:**
- Loops.so templates created with correct IDs
- Loops API key configured
- Email address is correct
- Check spam folder

---

## 📊 Cost Reference

**Test Mode (Development):**
- Free
- No actual postcards mailed
- Full API functionality

**Live Mode (Production):**
- 6x9 postcard: $1.05 each
- 100 postcards: $105.00
- 1,000 postcards: $1,050.00

---

## 📞 Need Help?

**Documentation:**
- Full spec: `.docs/lob-postcard-integration-mvp.md`
- Implementation guide: `.docs/lob-implementation-guide.md`
- Build summary: `.docs/BUILD-SUMMARY.md`

**External Resources:**
- Lob Docs: https://docs.lob.com/
- Lob Support: https://support.lob.com/
- Loops Docs: https://loops.so/docs

---

## ✨ You're Ready!

Once all checkboxes are complete, you're ready to send postcards! 

Start with a test campaign to yourself, then scale up to your customers.

**Happy mailing!** 📮✨

