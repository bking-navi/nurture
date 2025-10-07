# Agency Partner Feature - Deployment Checklist

## ✅ Completed Features

### Platform Admin
- ✅ Platform admin role with encrypted storage
- ✅ Admin dashboard showing all advertisers, agencies, users
- ✅ Agency creation UI
- ✅ Advertiser management
- ✅ User directory with membership details
- ✅ Platform context switcher in sidebar

### Agency Partners
- ✅ Agency model with owner, address, website
- ✅ Agency membership (owner, admin, manager, viewer roles)
- ✅ Agency dashboard showing clients and team
- ✅ Agency team management page
- ✅ Agency team invitation system (email + acceptance flow)
- ✅ Advertiser-to-Agency invitation system
- ✅ Agency access revocation and re-invitation
- ✅ Client assignment system (assign team members to specific clients)
- ✅ Agency context in sidebar and navigation

### Access Control
- ✅ Agency users can see assigned clients in sidebar
- ✅ Agency users can view advertiser dashboards
- ✅ Context switching between platform/advertisers/agencies
- ⚠️  **NEEDS FIX**: Permission checks for campaigns, contacts, segments, creatives

### UI/UX
- ✅ Context switcher shows all user contexts
- ✅ Agency clients display with "Agency" badge
- ✅ Advertiser dashboard shows correct role badge for agency users
- ✅ Empty states for all major views
- ✅ Consistent navigation across contexts

---

## 🔴 Critical Issues to Fix Before Deploy

### 1. **Permission Methods Don't Check Agency Access**

**Location**: `app/models/user.rb`

**Problem**: Methods like `can_manage_campaigns?` only check direct advertiser membership, not agency assignments.

**Impact**: Agency users can VIEW advertiser dashboards but CANNOT manage campaigns, contacts, segments, or creatives.

**Fix Required**: Update permission methods to check both direct membership AND agency assignments.

### 2. **Missing Loops Email Template**

**Template ID**: `agency_team_invitation`

**Variables**:
- `agency_name`
- `inviter_name`
- `role`
- `invitation_url`
- `expires_at`

**Action**: Create template in Loops dashboard before deploying.

---

## ⚠️  Potential Issues to Review

### 3. **Data Scoping for Agency Users**

**Question**: When an agency user creates a campaign/contact/segment, should it be:
- Associated with their agency?
- Show their agency user as creator?
- Have any limitations compared to direct members?

**Current Behavior**: Creates as normal, associated with advertiser.

**Recommendation**: Add `created_by_agency_id` field to track agency-created resources (optional, for future analytics).

### 4. **Permission Levels**

**Question**: Should agency assignment roles (viewer/manager/admin) map to advertiser roles?

**Current Behavior**: Not enforced - all agency users with assignments have same access.

**Recommendation**: 
- Viewer: Read-only access
- Manager: Can manage campaigns, contacts, segments
- Admin: Full access except billing/settings

### 5. **Agency Access Audit Trail**

**Missing**: No log of when agency users access advertiser accounts or perform actions.

**Recommendation**: Add audit logging for compliance (future feature).

### 6. **Billing & Plan Limits**

**Question**: Do agency-accessed advertisers count toward any limits? Who pays for sends from agency-created campaigns?

**Current Behavior**: Not addressed.

**Recommendation**: Document billing model.

---

## 🧪 Testing Checklist

Before deploying, manually test these flows:

### Platform Admin Flow
- [ ] Platform admin can view all advertisers
- [ ] Platform admin can view all agencies
- [ ] Platform admin can view all users
- [ ] Platform admin can create agencies
- [ ] Platform admin can switch to advertiser/agency contexts

### Agency Owner/Admin Flow
- [ ] Can see agency dashboard with all clients
- [ ] Can invite team members via email
- [ ] Can assign team members to specific clients
- [ ] Can accept advertiser-to-agency invitations
- [ ] Can view assigned clients in sidebar
- [ ] Can switch between agency and client contexts

### Agency Team Member Flow
- [ ] Can accept agency team invitation
- [ ] Only sees assigned clients in sidebar
- [ ] Can view assigned client dashboards
- [ ] Can manage campaigns for assigned clients (AFTER FIX #1)
- [ ] Cannot see other agency clients they're not assigned to

### Advertiser Owner/Admin Flow
- [ ] Can invite agencies by owner email
- [ ] Can see invited agencies in settings
- [ ] Can revoke agency access
- [ ] Can re-invite previously revoked agencies
- [ ] Agency shows in "Agency Partners" settings page

### Email Flows
- [ ] Advertiser invites agency → agency owner receives email
- [ ] Agency owner accepts → access granted
- [ ] Agency admin invites team member → member receives email
- [ ] Team member accepts → joins agency
- [ ] Team member is assigned to client → can access client

---

## 📝 Database Migrations

All migrations completed:
- ✅ `add_platform_role_to_users`
- ✅ `create_agencies`
- ✅ `create_agency_memberships`
- ✅ `create_advertiser_agency_accesses`
- ✅ `create_agency_client_assignments`
- ✅ `create_agency_invitations`

---

## 🚀 Deployment Steps

1. **Fix Permission Methods** (Critical - see below)
2. **Create Loops Email Template** for `agency_team_invitation`
3. **Run Manual Tests** (use checklist above)
4. **Deploy to Staging**
5. **Test on Staging**
6. **Deploy to Production**
7. **Grant Platform Admin** to yourself via Rails console:
   ```ruby
   user = User.find_by(email: 'your@email.com')
   user.grant_platform_admin!
   ```

---

## 📋 Post-Deployment Tasks

- [ ] Create first test agency
- [ ] Test full invitation flow
- [ ] Document agency onboarding process
- [ ] Add agency features to product documentation
- [ ] Consider rate limiting for invitations
- [ ] Monitor for email delivery issues

---

## 🔧 Code Quality

### Missing Tests
- No test coverage for agency features
- Recommendation: Add integration tests for critical flows

### Documentation
- This file documents the feature
- Consider adding inline documentation for complex permission logic

### Performance
- Sidebar query for agency clients might be slow with many clients
- Consider caching or eager loading optimization if needed

---

## 🎯 Future Enhancements (Not Required for Launch)

1. **Agency Branding**: Allow agencies to add logo/branding
2. **Client Reports**: Agency-specific reporting dashboard
3. **Bulk Client Assignment**: Assign multiple team members at once
4. **Role-Based Permissions**: Enforce viewer/manager/admin roles
5. **Audit Logging**: Track all agency user actions
6. **Agency Billing**: Separate billing for agency vs advertiser
7. **Client Invitations**: Let agencies invite their clients to platform
8. **White Label**: Agency-branded login/interface
9. **Multi-Agency**: Allow advertisers to work with multiple agencies simultaneously (already supported by data model!)
10. **Agency Settings**: Custom settings per agency (timezone, default sending preferences, etc.)

---

## 📞 Support

If issues arise post-deployment:
- Check logs for email delivery failures
- Verify Loops API key is configured
- Check database for orphaned records
- Review permission denials in application logs

