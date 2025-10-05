# Campaign Status Flow

## Overview
Campaign statuses now accurately reflect the reality of postcard fulfillment. A campaign is only marked "completed" if postcards were actually sent successfully.

## Campaign Statuses

### 1. **Draft** (0)
- Initial state when campaign is created
- User is still adding recipients and configuring design
- Campaign can be edited and deleted
- Not yet sent to Lob

### 2. **Scheduled** (1)
- Campaign is scheduled for future sending
- Post-MVP feature
- User can cancel or reschedule

### 3. **Processing** (2)
- Campaign send has been initiated
- Background job is actively sending postcards to Lob
- Cannot be edited or cancelled

### 4. **Completed** (3) ✅
- **All postcards sent successfully**
- No failures
- This is the ideal success state
- Shows green badge in UI

### 5. **Completed with Errors** (4) ⚠️
- **Some postcards sent, some failed**
- Mixed success/failure state
- Failed postcards can be retried individually
- Shows yellow/warning badge in UI
- User sees which specific postcards failed

### 6. **Failed** (5) ❌
- **All postcards failed to send** OR campaign-level error occurred
- No successful sends
- Shows red badge in UI
- User receives failure email
- Can retry individual postcards

### 7. **Cancelled** (6)
- User cancelled a scheduled campaign
- Post-MVP feature

## Status Flow Diagram

```
Draft ──────→ Processing ──────→ Completed ✅
                   │                (all sent)
                   │
                   ├──────→ Completed with Errors ⚠️
                   │         (some sent, some failed)
                   │
                   └──────→ Failed ❌
                             (all failed)
```

## Key Differences from Before

### Before (Incorrect):
- Campaign marked as "sent" even if postcards failed
- No distinction between partial and complete success
- "Failed" status used for both some failures and all failures

### After (Correct):
- **Completed**: Only when ALL postcards actually sent
- **Completed with Errors**: Honest about partial failures
- **Failed**: Only when ALL postcards failed or system error

## Contact (Postcard) Statuses

Individual postcards have their own lifecycle:

1. **Pending** (0) - Waiting to be sent
2. **Validated** (1) - Address verified with Lob
3. **Sending** (2) - API call in progress
4. **Sent** (3) - Successfully submitted to Lob
5. **In Transit** (4) - USPS has postcard, tracking updated
6. **Delivered** (5) - Confirmed delivered by USPS
7. **Returned** (6) - Returned to sender (bad address)
8. **Failed** (7) - Failed to send via Lob API

## Retry Logic

When postcards fail:
- Campaign status reflects reality (completed_with_errors or failed)
- User sees prominent warning banner
- Each failed postcard shows "Retry" button
- Retry attempts to resend immediately
- Campaign counts and costs update after successful retry

## UI Indicators

### Badge Colors:
- 🔵 **Blue**: Processing
- ✅ **Green**: Completed (all successful)
- ⚠️ **Yellow**: Completed with errors (needs attention)
- ❌ **Red**: Failed
- ⚪ **Gray**: Draft, Cancelled

### Status Display:
- "Completed" - Perfect, all sent
- "Completed (with errors)" - Readable, indicates action needed
- "Failed" - Clear failure state

## Email Notifications

### Campaign Sent Email (campaign_sent)
Sent when:
- Status = completed OR
- Status = completed_with_errors

Includes:
- Number of postcards sent successfully
- Number of failures (if any)
- Link to view campaign

### Campaign Failed Email (campaign_failed)
Sent when:
- Status = failed (all postcards failed)

Includes:
- Error details
- Link to retry
- Support contact

## Database Migration

The status enum values were updated with a migration that:
1. Preserved existing draft/scheduled/processing campaigns
2. Converted old "sent" (3) → checks for failures → "completed" or "completed_with_errors"
3. Moved old "failed" (4) → new "failed" (5)
4. Moved old "cancelled" (5) → new "cancelled" (6)

## Testing Recommendations

1. **Happy Path**: Send campaign with 1 recipient → Status = "Completed"
2. **Partial Failure**: Cause 1 of 2 postcards to fail → Status = "Completed with errors"
3. **Total Failure**: Cause all postcards to fail → Status = "Failed"
4. **Retry Success**: Retry failed postcard → Updates counts and costs
5. **UI Badges**: Verify colors match status

## Benefits

✅ **Accurate Fulfillment State**: Users know exactly what happened
✅ **Clear Action Required**: Yellow badge = needs attention
✅ **No False Positives**: "Completed" truly means completed
✅ **Honest Reporting**: Dashboards show real success rates
✅ **Retry Support**: Failed sends can be individually retried

---

**Last Updated**: October 2025

