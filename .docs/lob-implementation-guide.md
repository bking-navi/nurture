# Lob Postcard Campaign Implementation Guide

## ✅ What We Built

A complete MVP for creating and sending postcard campaigns via Lob.com, including:

### Core Features
- ✅ Create campaigns with name and description
- ✅ Save drafts and edit before sending
- ✅ Add recipients manually (one at a time)
- ✅ Upload recipients via CSV
- ✅ Select postcard template (starting with one default)
- ✅ Cost estimation before sending
- ✅ Send campaigns to 1 or many recipients
- ✅ Track delivery status per postcard
- ✅ Delete draft campaigns
- ✅ Email notifications on completion
- ✅ Manager+ permission level for campaigns

### Technical Implementation
- **Models**: Campaign, CampaignContact with full validations
- **Controllers**: CampaignsController, CampaignContactsController
- **Services**: LobClient (API wrapper), CsvImporter
- **Jobs**: SendCampaignJob, UpdatePostcardStatusesJob
- **Mailer**: CampaignMailer for notifications
- **Views**: Complete UI with tabbed campaign editor
- **Routes**: RESTful routes nested under advertisers

---

## 🚀 Setup Instructions

### 1. Set Up Lob API Keys

```bash
# Edit Rails credentials
EDITOR="code --wait" rails credentials:edit

# Add your Lob keys:
lob:
  test_api_key: test_YOUR_KEY_HERE
  live_api_key: live_YOUR_KEY_HERE
```

Or use environment variables:
```bash
export LOB_TEST_API_KEY=test_your_key_here
export LOB_API_KEY=live_your_key_here
```

### 2. Set Up Loops Email Templates

Create two transactional email templates in Loops.so:

#### Template: `campaign_sent`
**Subject:** Your postcard campaign has been sent

**Variables:**
- `campaign_name` (string)
- `postcards_sent` (number)
- `postcards_failed` (number)
- `total_cost` (string, e.g. "$1,295.70")
- `campaign_url` (string)

#### Template: `campaign_failed`
**Subject:** Action needed: Campaign failed to send

**Variables:**
- `campaign_name` (string)
- `error_message` (string)
- `campaign_url` (string)
- `support_url` (string)

### 3. Update Advertiser State Format

If you have existing advertisers with full state names, update them to 2-letter codes:

```ruby
# In rails console
Advertiser.all.each do |a|
  # Example: convert "California" to "CA"
  a.update(state: a.state.upcase[0..1]) if a.state.length > 2
end
```

### 4. Run Migrations

```bash
rails db:migrate
```

---

## 📋 User Flow

### Creating a Campaign

1. **Navigate to Campaigns**
   - From dashboard: Click "Campaigns" in nav or "Quick Actions" card
   - URL: `/advertisers/:slug/campaigns`

2. **Create New Campaign**
   - Click "Create Campaign"
   - Enter campaign name and optional description
   - Click "Create Campaign" - saves as draft

3. **Add Recipients (Tab 1)**
   - **Option A - Manual Entry:**
     - Click "Add Manually"
     - Fill in recipient details (name, address)
     - Click "Add Recipient"
   
   - **Option B - CSV Upload:**
     - Click "Upload CSV"
     - Select CSV file with required columns
     - Click "Import Recipients"
     - Download sample CSV for reference

4. **Select Template (Tab 2)**
   - Standard 6x9 postcard template (pre-selected for MVP)
   - Optionally add custom messages for front/back
   - Use variables: `{{first_name}}`, `{{last_name}}`, `{{full_name}}`
   - Click "Save Changes"

5. **Review & Send (Tab 3)**
   - Review campaign summary
   - Click "Calculate Cost" to see total
   - Review readiness checklist
   - Click "Send Campaign Now"
   - Confirm sending (final warning modal via browser confirm)

6. **Campaign Sent**
   - Status changes to "Processing"
   - Background job creates postcards via Lob
   - Email notification sent when complete
   - View delivery status for each recipient

---

## 💰 Cost Structure

**Postcard Pricing:**
- 6x9 postcard: $1.05 each (USPS First Class)
- Estimated before sending
- Actual cost tracked per postcard

**Example:**
- 100 postcards = $105.00
- 1,000 postcards = $1,050.00

---

## 🛠️ Development & Testing

### Test with Lob Test Mode

Development automatically uses test API key (configured in initializer):
- No actual postcards mailed
- No charges incurred
- Realistic API responses
- Full delivery tracking simulation

### Manual Testing Checklist

```bash
# 1. Start Rails server
bin/dev

# 2. Navigate to campaigns
# Visit: http://localhost:3000/advertisers/YOUR_SLUG/campaigns

# 3. Create test campaign
# - Add 2-3 test recipients
# - Use your own address for recipients
# - Select template
# - Calculate cost
# - Send campaign

# 4. Check background job
# Watch Solid Queue process the SendCampaignJob

# 5. Verify email notification
# Check that Loops sends completion email

# 6. View sent campaign
# Check delivery statuses update
```

### CSV Format

Download sample CSV from UI, or use this format:

```csv
first_name,last_name,company,address_line1,address_line2,city,state,zip,email,phone
John,Doe,Acme Corp,1234 Main St,,San Francisco,CA,94111,john@example.com,555-1234
Jane,Smith,,5678 Oak Ave,Apt 2,Los Angeles,CA,90001,jane@example.com,
```

**Required columns:**
- `first_name`, `last_name`, `address_line1`, `city`, `state`, `zip`

**Optional columns:**
- `company`, `address_line2`, `email`, `phone`

---

## 📊 Monitoring

### Check Campaign Status

```ruby
# Rails console
campaign = Campaign.find(ID)

campaign.status               # draft, processing, sent, failed
campaign.recipient_count      # Total recipients
campaign.sent_count          # Successfully sent
campaign.failed_count        # Failed to send
campaign.delivered_count     # Delivered postcards
campaign.actual_cost_dollars # Total cost
```

### Check Background Jobs

```bash
# View Solid Queue dashboard
# Visit: http://localhost:3000/solid_queue (if configured)

# Or in rails console
SendCampaignJob.queue_adapter
```

### Update Delivery Statuses

Run this job daily via cron to update postcard statuses:

```ruby
UpdatePostcardStatusesJob.perform_now
```

For Rails 8 with solid_queue, add to `config/recurring.yml`:

```yaml
update_postcard_statuses:
  class: "UpdatePostcardStatusesJob"
  schedule: "0 2 * * *"  # Daily at 2 AM
```

---

## 🔒 Permissions

**Who can manage campaigns:**
- Owner
- Admin
- Manager

**Who CANNOT:**
- Viewer

Permission check: `current_user.can_manage_campaigns?(advertiser)`

---

## 🚧 Known Limitations (MVP)

1. **Single Template**: Only one default template available (more coming post-MVP)
2. **No Scheduling**: Campaigns send immediately (scheduling planned for post-MVP)
3. **No Reusable Contacts**: Recipients stored per-campaign (Shopify integration will add contact library)
4. **No Custom Creative**: Can't upload PDFs yet (post-MVP feature)
5. **Manual Status Updates**: Delivery status updates via daily job, not real-time webhooks

---

## 🎯 Post-MVP Roadmap

### Phase 2: Scheduling (1 week)
- Schedule campaigns for future dates
- Cancel/reschedule before send date
- Email reminders

### Phase 3: More Templates (1 week)
- Multiple Lob templates to choose from
- Upload custom PDF designs
- Template library per advertiser

### Phase 4: Shopify Integration (from existing spec)
- Link campaigns to Shopify contacts
- Segment builder
- Send to filtered lists

### Phase 5: Automation (2-3 weeks)
- Triggered postcards (new customer, birthday, etc.)
- Abandoned cart campaigns
- Multi-step sequences

---

## 🐛 Troubleshooting

### "Lob API key not configured"

**Solution:** Add Lob API keys to Rails credentials or environment variables

### Campaign stuck in "Processing"

**Check:**
1. Background job queue is running
2. Lob API credentials are valid
3. Check job errors in Solid Queue
4. Review `rails log` for errors

### CSV import fails

**Common issues:**
- Missing required columns
- Invalid state codes (must be 2-letter uppercase)
- Invalid ZIP codes (must be 5 or 9 digits)
- Invalid email format

**Solution:** Download sample CSV and match format exactly

### Address validation fails

**Check:**
- Address is a valid US address
- State is 2-letter code (CA, NY, TX, etc.)
- ZIP code is valid format
- No typos in street address

---

## 📝 Database Schema

### campaigns
- Campaign metadata, status, costs
- Belongs to advertiser and creator user
- Has many campaign_contacts

### campaign_contacts
- Individual recipients with addresses
- Lob postcard tracking info
- Delivery status and costs
- Belongs to campaign

---

## 🔧 Maintenance

### Daily Tasks (Automated)
- UpdatePostcardStatusesJob updates delivery statuses

### Weekly Tasks (Manual)
- Review failed campaigns
- Check cost tracking accuracy
- Monitor Lob API usage

### Monthly Tasks (Manual)
- Review campaign performance
- Update templates if needed
- Check for Lob gem updates

---

## 📞 Support

**Lob API Issues:**
- Docs: https://docs.lob.com/
- Support: https://support.lob.com/

**App Issues:**
- Check logs: `tail -f log/development.log`
- Rails console debugging: `rails console`
- Background jobs: Solid Queue dashboard

---

## ✨ Success!

You now have a fully functional postcard campaign system! Users can create campaigns, upload recipients, and send real postcards via Lob.com.

**Next steps:**
1. Test with Lob test API key
2. Create test campaigns
3. Verify email notifications work
4. Switch to live API key for production
5. Send your first real campaign! 🎉

