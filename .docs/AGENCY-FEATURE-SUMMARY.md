# Agency Partner Feature - Complete Summary

## Overview
This document summarizes the Agency Partner and Platform Admin features added to Nurture. These features enable multi-tenant access with three distinct user types: Platform Admins, Agency Partners, and Advertisers.

---

## Architecture

### User Types

1. **Platform Admin**
   - System-level superuser role
   - Can view/manage all advertisers and agencies
   - Access via encrypted `platform_role` field
   - Special context in sidebar (purple "P" badge)

2. **Agency Partner**
   - Marketing agencies that manage campaigns for clients
   - Has its own team members (owner, admin, manager, viewer)
   - Can be granted access to multiple advertiser accounts
   - Team members can be assigned to specific clients

3. **Advertiser** (existing, enhanced)
   - Brands/businesses using the platform
   - Can invite agencies to help manage their account
   - Can revoke agency access at any time
   - Full control over their data

### Key Concepts

**Multi-context Users**: Users can belong to multiple advertisers AND multiple agencies simultaneously. The sidebar context switcher allows seamless navigation between all contexts.

**Two-tier Agency Access**:
1. **Agency Level**: Agency is invited by advertiser, agency owner/admin accepts
2. **User Level**: Agency owner/admin assigns specific team members to specific clients

**Permission Hierarchy**:
- **Direct members** (owner/admin) can access settings, billing, team management
- **Agency users** can manage campaigns, contacts, segments based on their assignment role
- **Agency assignment roles**:
  - Viewer: Read-only access
  - Manager: Can manage campaigns and contacts
  - Admin: Full access except sensitive settings

---

## Database Schema

### New Tables

#### `agencies`
- Core agency data (name, slug, address, website)
- Similar structure to advertisers
- Settings stored as JSON

#### `agency_memberships`
- Join table: users ↔ agencies
- Roles: owner, admin, manager, viewer
- Status: pending, accepted, declined
- Only one owner per agency enforced

#### `advertiser_agency_accesses`
- Join table: advertisers ↔ agencies
- Manages invitation and access status
- Status: pending, accepted, revoked
- Unique constraint on (advertiser_id, agency_id)
- Supports re-invitation after revocation

#### `agency_client_assignments`
- Assigns specific agency users to specific clients
- Join table: agency_memberships ↔ advertiser_agency_accesses
- Roles: viewer, manager, admin (separate from agency role)
- Unique constraint prevents duplicate assignments

#### `agency_invitations`
- Agency team member invitations
- Similar to advertiser invitations
- Email-based, 7-day expiration
- Token-based acceptance flow

### Modified Tables

#### `users`
- Added `platform_role` (encrypted, nullable)
- Added `platform_role_encrypted` for deterministic encryption

---

## Routes Structure

```
# Platform Admin
/platform/admin/dashboard          # Admin dashboard
/platform/admin/advertisers        # List all advertisers
/platform/admin/advertisers/:id    # View advertiser details
/platform/admin/agencies           # List all agencies
/platform/admin/agencies/new       # Create agency
/platform/admin/agencies/:id       # View agency details
/platform/admin/users              # List all users
/platform/admin/users/:id          # View user details

# Agency Management (advertiser side)
/advertisers/:slug/settings/agencies      # Manage agency partners
/advertisers/:slug/settings/agencies/new  # Invite agency
/agency_invitations/:token/accept         # Accept agency invitation (public)

# Agency Dashboard & Management
/agencies/:slug/dashboard           # Agency dashboard
/agencies/:slug/clients             # List agency clients
/agencies/:slug/clients/:id/assignments  # Manage client assignments
/agencies/:slug/team                # Agency team management
/agencies/:slug/team/invitations/invite  # Invite team member
/agencies/invitations/:token/accept # Accept team invitation (public)

# Advertiser Access (works for both direct and agency users)
/advertisers/:slug/dashboard        # Advertiser dashboard
/advertisers/:slug/campaigns        # Campaigns
/advertisers/:slug/audience         # Contacts
/advertisers/:slug/audience/segments # Segments
/advertisers/:slug/creative-library # Creative library
```

---

## Permission Matrix

| Action | Advertiser Owner/Admin | Advertiser Manager | Agency Admin | Agency Manager | Agency Viewer |
|--------|----------------------|-------------------|-------------|----------------|---------------|
| View dashboard | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manage campaigns | ✅ | ✅ | ✅ | ✅ | ❌ |
| Manage contacts | ✅ | ✅ | ✅ | ✅ | ❌ |
| Manage segments | ✅ | ✅ | ✅ | ✅ | ❌ |
| Manage creative | ✅ | ✅ | ✅ | ✅ | ❌ |
| View settings | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage team | ✅ | ❌ | ❌ | ❌ | ❌ |
| Manage agencies | ✅ | ❌ | ❌ | ❌ | ❌ |
| View billing | ✅ | ❌ | ❌ | ❌ | ❌ |

**Note**: Agency assignment role (viewer/manager/admin) is separate from their agency role. An agency viewer can be assigned as "admin" to a specific client.

---

## Email Templates (Loops.so)

### 1. Agency Client Invitation
**Template ID**: `agency_client_invitation` (or from credentials)

**When**: Advertiser invites an agency

**Recipient**: Agency owner

**Variables**:
- `agency_name`
- `advertiser_name`
- `inviter_name`
- `inviter_email`
- `invitation_url`
- `expires_in_days` (7)
- `expires_at` (formatted date)

### 2. Agency Team Invitation
**Template ID**: `agency_team_invitation`

⚠️ **STATUS**: NOT YET CREATED - must be created before deploy

**When**: Agency admin invites a team member

**Recipient**: Invited email

**Variables**:
- `agency_name`
- `inviter_name`
- `role` (admin/manager/viewer)
- `invitation_url`
- `expires_at` (formatted date)

---

## UI Components

### Context Switcher (Sidebar)
Shows all contexts user has access to:
- **Platform Admin**: Purple "P" badge (if platform admin)
- **Advertisers**: Gray badges (direct membership)
- **Agency Clients**: Green badges with "Agency" label
- **Agencies**: Green badges

Users can click to switch between any context.

### Navigation
Dynamically changes based on context:
- **Platform context**: Admin navigation
- **Agency context**: Clients, Team
- **Advertiser context**: Dashboard, Campaigns, Audience, etc.

### Badges & Indicators
- **Direct member role**: Purple (owner), Blue (admin), Green (manager/viewer)
- **Agency user role**: Green with "Agency [Role]"
- **Access status**: Pending (yellow), Active (green), Revoked (gray)

---

## Security Considerations

### Access Control
- All sensitive operations require authentication
- Settings/billing only accessible to direct members
- Agency users cannot modify advertiser team
- Platform admin cannot be granted via UI (must use Rails console)

### Data Isolation
- Agency users only see assigned clients
- Proper scoping in all queries
- Context-aware permissions throughout

### Encryption
- Platform role stored encrypted (deterministic)
- Credentials managed via Rails encrypted credentials

### Tokens
- Invitation tokens use `generates_token_for` (Rails 7.1+)
- 7-day expiration on all invitations
- Secure random tokens (URL-safe base64)

---

## Code Structure

### Models
- `User` - Extended with platform role, agency relationships, permission methods
- `Agency` - Core agency model
- `AgencyMembership` - User ↔ Agency relationship
- `AdvertiserAgencyAccess` - Advertiser ↔ Agency relationship
- `AgencyClientAssignment` - Agency user to client assignment
- `AgencyInvitation` - Agency team invitations
- `Advertiser` - Extended with agency relationships
- `AdvertiserMembership` - Enhanced with status helpers

### Controllers
- `Platform::Admin::*` - Platform admin controllers
- `Agencies::*` - Agency-scoped controllers
- `Settings::AgenciesController` - Advertiser-side agency management
- `AgenciesController` - Agency context switching (if needed)
- `AdvertisersController` - Enhanced to support agency access

### Concerns
- `PlatformRole` - Platform admin role logic for User model

### Views
- `platform/admin/*` - Platform admin views
- `agencies/*` - Agency dashboard and management
- `settings/agencies/*` - Advertiser agency management
- `layouts/sidebar.html.erb` - Enhanced with context switcher

---

## Testing Recommendations

### Critical Paths
1. **Platform admin flow**:
   - View all entities
   - Create agency
   - Switch contexts

2. **Agency invitation flow**:
   - Advertiser invites agency
   - Agency accepts
   - Agency can view client

3. **Team member flow**:
   - Agency invites member
   - Member accepts
   - Member assigned to client
   - Member can access client

4. **Permission boundaries**:
   - Agency users cannot access settings
   - Non-assigned users cannot see clients
   - Viewers cannot manage campaigns

### Edge Cases
- User belongs to same advertiser as both direct member and agency user
- Agency owner email not found when inviting
- Expired invitation handling
- Revoked agency re-invitation
- Multiple agency assignments to same client

---

## Configuration

### Environment Variables
```bash
APP_HOST=localhost:3000  # or production domain
```

### Rails Credentials
```yaml
loops:
  api_key: xxx
  templates:
    agency_client_invitation: cmggixjunce0tyh0iuoqfuete
    agency_team_invitation: [TO BE CREATED]
```

### Database
- All migrations created and reversible
- Indices on foreign keys and frequently queried fields
- Unique constraints prevent duplicates

---

## Deployment Checklist

See `AGENCY-DEPLOYMENT-CHECKLIST.md` for full checklist.

**Critical before deploy**:
1. ✅ Permission methods updated to support agency access
2. ❌ Create `agency_team_invitation` email template in Loops
3. ❌ Manual testing of all flows
4. ❌ Grant platform admin access to yourself

---

## Post-Deployment

### Grant Platform Admin
```ruby
# In Rails console
user = User.find_by(email: 'your@email.com')
user.grant_platform_admin!
```

### Create First Agency
Use Platform Admin UI:
1. Switch to Platform Admin context
2. Go to Agencies → Create Agency
3. Enter agency details + owner email
4. Agency owner will see agency in their context switcher

### Monitor
- Email delivery success rates
- Invitation acceptance rates
- Permission denial errors
- Context switching errors

---

## Future Enhancements

See `AGENCY-DEPLOYMENT-CHECKLIST.md` for full list.

Top priorities:
1. Enforce role-based permissions (viewer read-only)
2. Audit logging for compliance
3. Agency-specific reporting
4. Bulk user assignment
5. Performance optimization for sidebar queries

---

## Support & Troubleshooting

### Common Issues

**Agency doesn't see client in dashboard**:
- Verify advertiser has invited agency
- Verify agency has accepted invitation
- Verify user is assigned to that client
- Check status is "accepted" not "pending" or "revoked"

**User can't manage campaigns**:
- Verify they have manager or admin assignment role
- Verify permission methods include agency check (post-fix)
- Check console for permission errors

**Email not sending**:
- Verify Loops API key configured
- Check template ID exists
- Review application logs for errors
- Verify email address is valid

**Context switcher not showing clients**:
- User must be assigned to client by agency admin
- Client access must be "accepted" status
- Try refreshing the page

### Debug Queries

```ruby
# Check user's agency access
user = User.find_by(email: 'user@example.com')
user.agency_client_assignments.includes(:advertiser_agency_access, :agency).each do |a|
  puts "#{a.advertiser.name} via #{a.agency.name} - #{a.role} (#{a.advertiser_agency_access.status})"
end

# Check agency's clients
agency = Agency.find_by(slug: 'agency-slug')
agency.advertiser_agency_accesses.includes(:advertiser).each do |access|
  puts "#{access.advertiser.name} - #{access.status}"
end

# Check client assignments for an advertiser
advertiser = Advertiser.find_by(slug: 'advertiser-slug')
AgencyClientAssignment.joins(:advertiser_agency_access)
  .where(advertiser_agency_accesses: { advertiser: advertiser })
  .includes(:user, :agency)
  .each do |assignment|
    puts "#{assignment.user.email} (#{assignment.agency.name}) - #{assignment.role}"
  end
```

---

## Documentation Location

- This file: `.docs/AGENCY-FEATURE-SUMMARY.md`
- Deployment checklist: `.docs/AGENCY-DEPLOYMENT-CHECKLIST.md`
- Original requirements: `.docs/nurture-auth-requirements.md`
- Build notes: `.docs/BUILD-SUMMARY.md` (if exists)

---

**Last Updated**: October 7, 2025
**Version**: 1.0
**Status**: Ready for Deployment (pending email template creation)

