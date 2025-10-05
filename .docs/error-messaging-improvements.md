# Error Messaging Improvements

## Overview
Enhanced error messages to clearly communicate address validation failures and other Lob API errors to users.

## Changes Made

### 1. Intelligent Error Parsing
Added `parse_lob_error` method that extracts meaningful error messages from Lob API responses.

**Location**: 
- `app/jobs/send_campaign_job.rb`
- `app/controllers/campaign_contacts_controller.rb`

**What it does**:
- Parses JSON error responses from Lob API
- Maps error codes to user-friendly messages
- Extracts the core issue without technical jargon

### 2. Address-Specific Error Messages

#### Error Code: `failed_deliverability_strictness`
**Before**: 
```
Error message: the server returns an error
HTTP status code: 422
Response headers: {...}
Response body: {...}
```

**After**:
```
❌ Address Undeliverable: This address failed USPS verification and cannot receive mail. Please verify the address is correct.
```

#### Error Code: `invalid_address`
**Message**: 
```
❌ Invalid Address: This address format is invalid. Please check street, city, state, and ZIP code.
```

#### Error Code: `address_length_exceeds_limit`
**Message**:
```
❌ Address Too Long: One or more address fields exceed the maximum length.
```

### 3. Enhanced UI Display

#### Individual Contact Errors
- Red bordered box with error icon
- Bold, readable error message
- Contextual tip for address errors
- Retry button prominently displayed

**Example**:
```
┌──────────────────────────────────────────────┐
│ 🛑 ❌ Address Undeliverable: This address   │
│    failed USPS verification...              │
│                                              │
│ 💡 Tip: Verify the street address, city,   │
│    state, and ZIP code are correct...      │
└──────────────────────────────────────────────┘
```

#### Campaign-Level Warning
When failures occur, the banner at the top now shows:
- Count of address-related failures
- Specific guidance about USPS verification
- Clear call to action

**Example**:
```
┌──────────────────────────────────────────────┐
│ 🛑 2 postcards failed to send               │
│                                              │
│ 2 failed due to undeliverable addresses     │
│                                              │
│ 📬 These addresses failed USPS              │
│    verification. Verify that street         │
│    addresses, cities, states, and ZIP       │
│    codes are correct.                       │
└──────────────────────────────────────────────┘
```

## Benefits

### For Users
✅ **Clear Diagnosis**: Know immediately why a postcard failed  
✅ **Actionable Guidance**: Understand what to fix  
✅ **No Technical Jargon**: Plain language explanations  
✅ **Visual Hierarchy**: Errors stand out with icons and colors  

### For Support
✅ **Reduced Confusion**: Users know what went wrong  
✅ **Self-Service**: Users can fix address issues themselves  
✅ **Fewer Tickets**: Clear errors = fewer "why did this fail?" questions  

### For Data Quality
✅ **Better Addresses**: Users motivated to verify data  
✅ **Fewer Failures**: Proactive guidance prevents issues  
✅ **Cost Savings**: Avoid wasting money on undeliverable mail  

## Common Error Scenarios

### Scenario 1: Fake/Test Address
**Trigger**: Using sample data like "1234 Main St"  
**Error**: "❌ Address Undeliverable..."  
**Solution**: Use a real, USPS-verified address

### Scenario 2: Typo in ZIP Code
**Trigger**: "9001" instead of "90001"  
**Error**: "❌ Address Undeliverable..."  
**Solution**: Correct the ZIP code

### Scenario 3: Missing Street Number
**Trigger**: "Main Street" without number  
**Error**: "❌ Invalid Address..."  
**Solution**: Add complete street address

### Scenario 4: Deliverability Strictness
**Trigger**: Address exists but has issues  
**Error**: "❌ Address Undeliverable..."  
**Options**: 
- Fix the address
- Lower strictness in Lob dashboard (testing only)

## Testing

### Test with Real Addresses
```ruby
# Good test address (will work)
{
  first_name: "Test",
  last_name: "User",
  address_line1: "185 Berry St Ste 6100",
  address_city: "San Francisco",
  address_state: "CA",
  address_zip: "94107"
}

# Bad test address (will fail with clear error)
{
  first_name: "Test",
  last_name: "User",
  address_line1: "1234 Fake Street",
  address_city: "Nowhere",
  address_state: "CA",
  address_zip: "99999"
}
```

### Expected Behavior
1. Campaign sent with bad address
2. Job processes and catches error
3. Contact marked as "failed"
4. Clear error message stored
5. UI shows prominent error with tip
6. User can retry after fixing address

## Future Enhancements

### Potential Additions
- [ ] Address autocomplete/validation during entry
- [ ] Bulk address verification before sending
- [ ] Link to USPS address lookup tool
- [ ] Automatic address correction suggestions
- [ ] Track common address error patterns
- [ ] Email notification specifically for address failures

---

**Last Updated**: October 2025

