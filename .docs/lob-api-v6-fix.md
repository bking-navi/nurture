# Lob API v6 Fix

## Issue
The Lob Ruby gem v6+ uses a completely different API structure compared to earlier versions. The old syntax `Lob::Postcard.create(...)` no longer works and causes the error:
```
undefined method `create' for Lob::Postcard:Class
```

## Solution
Updated all Lob API calls to use the new v6+ OpenAPI-based client structure:

### Changes Made

#### 1. `app/services/lob_client.rb`
- **create_postcard**: Now uses `PostcardsApi.new` and `PostcardEditable.new`
- **get_postcard**: Now uses `PostcardsApi.new` with `get(id)` method
- **list_templates**: Now uses `TemplatesApi.new`
- **verify_address**: Now uses `UsVerificationsApi.new` and `UsVerificationsWritable.new`
- **Added format_address_editable**: Returns `AddressEditable` objects required by v6 API

#### 2. `app/jobs/send_campaign_job.rb`
- Updated `from_address` to use `format_address_editable` instead of `format_address`

## API Patterns

### Old API (v5 and earlier)
```ruby
Lob::Postcard.create(
  to: { name: "...", address_line1: "..." },
  from: { name: "...", address_line1: "..." },
  ...
)
```

### New API (v6+)
```ruby
postcards_api = Lob::PostcardsApi.new

postcard_editable = Lob::PostcardEditable.new(
  to: Lob::AddressEditable.new(name: "...", address_line1: "..."),
  from: Lob::AddressEditable.new(name: "...", address_line1: "..."),
  ...
)

postcard = postcards_api.create(postcard_editable)
```

## Key Differences
1. **API Clients**: Each resource now has its own API client class (e.g., `PostcardsApi`, `TemplatesApi`)
2. **Model Objects**: Request data must be wrapped in model objects (e.g., `PostcardEditable`, `AddressEditable`)
3. **Method Names**: Some methods changed (e.g., `retrieve(id)` became `get(id)`)

## Testing
After this fix, you should be able to:
1. Create campaigns
2. Add recipients
3. Send postcards to Lob API
4. Track postcard delivery status

## Next Steps
- Set up your Lob API keys in Rails credentials (test key for development)
- Create actual postcard templates in Lob dashboard
- Test the full campaign send flow

