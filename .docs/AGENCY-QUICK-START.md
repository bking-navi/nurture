# Agency Feature - Quick Start Guide

## ⚡ Pre-Deployment (5 minutes)

### 1. Create Email Template in Loops
```
Template ID: agency_team_invitation
Subject: You've been invited to join {{agency_name}}

Body:
Hi there,

{{inviter_name}} has invited you to join {{agency_name}} as a {{role}}.

[Accept Invitation Button]
{{invitation_url}}

This invitation expires on {{expires_at}}.
```

### 2. Verify Credentials
```bash
rails credentials:edit
```

Ensure this exists:
```yaml
loops:
  api_key: xxx
  templates:
    agency_client_invitation: cmggixjunce0tyh0iuoqfuete
    agency_team_invitation: [YOUR_NEW_TEMPLATE_ID]
```

---

## 🚀 Deployment Steps

```bash
# 1. Commit and push
git add .
git commit -m "Add agency partner features"
git push origin main

# 2. Deploy (adjust for your setup)
# If using Render/Heroku/etc:
git push production main

# OR if using Kamal:
kamal deploy

# 3. Run migrations (if not auto-run)
rails db:migrate
```

---

## 👑 Grant Platform Admin

```bash
# SSH into production or open Rails console
rails console

# Grant yourself platform admin
user = User.find_by(email: 'your@email.com')
user.grant_platform_admin!

# Verify
user.platform_admin?  # => true
```

---

## 🧪 Quick Test Flow

### Test 1: Platform Admin
1. Log in
2. Click context switcher
3. Select "Platform Admin"
4. Verify you see dashboard with stats
5. Click "View all" on Users → should see user list
6. Navigate to Agencies → click "Create Agency"

### Test 2: Create Agency
1. In Platform Admin → Agencies → Create Agency
2. Fill in agency details (use your own email as owner)
3. Submit
4. Log out and back in
5. Verify agency appears in context switcher

### Test 3: Agency to Advertiser
1. Switch to an advertiser context
2. Go to Settings → Agency Partners
3. Click "Invite Agency"
4. Enter agency owner email
5. Check email for invitation
6. Click invitation link
7. Accept invitation
8. Switch to agency context
9. Verify advertiser appears in clients list

### Test 4: Assign Team Member
**As agency owner:**
1. Go to Settings → Team → Agency Partners → Invite Agency
2. Enter team member email with role "manager"
3. **As team member**: Check email, accept invitation
4. **As agency owner**: Go to Clients → [Client] → Manage Access
5. Assign team member with role "manager"
6. **As team member**: Log out/in
7. Verify client appears in sidebar under agency clients
8. Click client → verify dashboard access
9. Navigate to Campaigns → verify can create/edit

---

## 🔍 Verify Everything Works

### Permission Test Matrix

**As agency viewer (assigned to client)**:
- ✅ Can view advertiser dashboard
- ✅ Can view campaigns (read-only currently - enforcement TODO)
- ❌ Cannot access Settings
- ❌ Cannot manage advertiser team

**As agency manager (assigned to client)**:
- ✅ Can view advertiser dashboard
- ✅ Can create/edit campaigns
- ✅ Can manage contacts
- ✅ Can manage segments
- ❌ Cannot access Settings
- ❌ Cannot manage advertiser team

**As agency admin (assigned to client)**:
- ✅ Can view advertiser dashboard
- ✅ Can create/edit campaigns
- ✅ Can manage contacts
- ✅ Can manage segments
- ✅ Full access except sensitive settings
- ❌ Cannot access Settings/Billing
- ❌ Cannot manage advertiser team

### Context Switcher Test
Log in as a user with multiple contexts and verify:
- Platform Admin shows (if applicable)
- All direct advertisers show (gray badges)
- All agency clients show (green badges with "Agency" label)
- All agencies show (green badges)
- Can switch between all contexts
- Navigation updates correctly per context

---

## 🐛 Common Issues & Fixes

### Issue: Email not sending
```ruby
# In Rails console, test email manually:
invitation = AgencyInvitation.last
invitation.send_invitation_email

# Check logs for errors
# Verify API key: Rails.application.credentials.dig(:loops, :api_key)
# Verify template: Rails.application.credentials.dig(:loops, :templates, :agency_team_invitation)
```

### Issue: Agency user can't see client
```ruby
# Check assignment exists and is accepted
user = User.find_by(email: 'agency-user@example.com')
advertiser = Advertiser.find_by(slug: 'client-slug')

# Should return true
user.has_access_to?(advertiser)

# Debug query
AgencyClientAssignment.joins(:advertiser_agency_access, :agency_membership)
  .where(agency_memberships: { user: user })
  .where(advertiser_agency_accesses: { advertiser: advertiser, status: 'accepted' })
  .first
```

### Issue: Context switcher not showing clients
- Clear browser cache
- Check user has assignment: `user.agency_client_assignments.count`
- Verify access is accepted: `AdvertiserAgencyAccess.find(X).status`
- Check query in sidebar view doesn't have errors in logs

---

## 📊 Monitor These Metrics

### First Week
- Number of platform admin logins
- Number of agencies created
- Number of advertiser→agency invitations
- Number of agency→team invitations
- Email delivery success rate
- Permission denial errors in logs

### Ongoing
- Context switching frequency
- Agency user campaign creation rate
- Average number of clients per agency
- Average team size per agency

---

## 🆘 Rollback Plan

If critical issues arise:

```bash
# Option 1: Rollback deployment
git revert HEAD
git push origin main
# Deploy previous version

# Option 2: Disable agency features via feature flag (if you add one)
# In Rails console:
Rails.cache.write('agency_features_enabled', false)

# Option 3: Remove platform admin access to prevent usage
User.where.not(platform_role: nil).update_all(platform_role: nil)
```

Database rollback (CAREFUL):
```bash
# Only if absolutely necessary and no agencies created yet
rails db:rollback STEP=6
```

---

## 📞 Support Contacts

**For deployment issues**:
- Check logs: `tail -f log/production.log`
- Application errors: Use your error tracking (Sentry/Rollbar/etc)

**For email issues**:
- Loops.so dashboard: Check email delivery status
- Verify templates exist and are published

**For data issues**:
- Use debug queries in "Common Issues" section
- Check database directly if needed

---

## ✅ Done!

Your platform now supports:
- ✅ Platform Admins with system-wide access
- ✅ Agency Partners with multi-client management
- ✅ Flexible user contexts and switching
- ✅ Granular permission control
- ✅ Secure invitation flows

**Next steps after deployment**:
1. Document agency onboarding process for customers
2. Add feature to marketing site/docs
3. Monitor usage and gather feedback
4. Implement viewer read-only enforcement (if needed)
5. Add audit logging (future enhancement)

---

**Questions?** Refer to:
- Full summary: `.docs/AGENCY-FEATURE-SUMMARY.md`
- Deployment checklist: `.docs/AGENCY-DEPLOYMENT-CHECKLIST.md`
- Original requirements: `.docs/nurture-auth-requirements.md`

