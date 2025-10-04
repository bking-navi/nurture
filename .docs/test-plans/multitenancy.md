# Multitenancy & Authorization Test Plan

This document outlines all critical test cases for authentication, authorization, multitenancy, and data isolation in the Nurture platform.

## Overview

The system implements **two-layer security**:
1. **Controller-level authorization** - Checks user membership and roles
2. **Model-level scoping** - Automatic query filtering via `AdvertiserScoped` concern

## Test Categories

### 1. Account Creation & Authentication

#### 1.1 Sign Up Flow
- [ ] User can sign up with valid email, password, first name, last name
- [ ] Password must be at least 12 characters
- [ ] After signup, user is redirected to "check your email" page
- [ ] Email verification link is sent via Loops.so
- [ ] Clicking verification link confirms email and redirects to advertiser creation

#### 1.2 Sign In Flow
- [ ] User can sign in with valid credentials
- [ ] User sees error with invalid credentials
- [ ] User can sign in even if email not verified (shows notice)
- [ ] After sign in, user is redirected to appropriate page based on context

#### 1.3 Email Verification
- [ ] Email verification link works and confirms email
- [ ] Already-confirmed emails show appropriate message
- [ ] User can resend verification email
- [ ] Expired verification links are handled gracefully

---

### 2. Advertiser Creation & Management

#### 2.1 First Advertiser Creation
- [ ] After email verification, user is prompted to create advertiser
- [ ] User must provide: business name, address, website
- [ ] Slug is automatically generated from business name
- [ ] User becomes the "owner" of the advertiser automatically
- [ ] After creation, user is redirected to advertiser dashboard

#### 2.2 Additional Advertiser Creation
- [ ] From advertisers index, user can click "Create New Advertiser"
- [ ] User becomes owner of new advertiser
- [ ] New advertiser is completely independent from other advertisers
- [ ] User can see both advertisers in their list

#### 2.3 Advertiser Index Page
- [ ] Shows all advertisers user has access to
- [ ] Shows user's role for each advertiser (Owner/Admin/Manager/Viewer)
- [ ] Role badges are color-coded (Owner=purple, Admin=blue, Manager=green, Viewer=gray)
- [ ] "Create New Advertiser" button is visible
- [ ] Can click any advertiser to navigate to its dashboard

---

### 3. Switching Between Advertisers

#### 3.1 Navigation
- [ ] "My Advertisers" link appears in nav bar on all advertiser pages
- [ ] Clicking "My Advertisers" shows full list
- [ ] Clicking an advertiser card navigates to that advertiser's dashboard
- [ ] URL updates to show current advertiser's slug

#### 3.2 Context Switching
- [ ] Switching advertisers changes all visible data
- [ ] Team members shown are specific to current advertiser
- [ ] Invitations shown are specific to current advertiser
- [ ] Cannot see data from other advertisers

---

### 4. User Roles & Permissions

#### 4.1 Owner Role
- [ ] Owner can invite team members
- [ ] Owner can change any role (except their own)
- [ ] Owner can remove any member (except themselves)
- [ ] Owner role is shown with purple badge
- [ ] Owner cannot change their own role via UI
- [ ] Only one owner per advertiser

#### 4.2 Admin Role
- [ ] Admin can invite team members
- [ ] Admin can change roles for manager/viewer (not owner or other admins)
- [ ] Admin can remove manager/viewer (not owner or other admins)
- [ ] Admin role is shown with blue badge
- [ ] Admin cannot see "Owner" option in role dropdowns

#### 4.3 Manager Role
- [ ] Manager can view team page
- [ ] Manager CANNOT invite team members
- [ ] Manager CANNOT change roles
- [ ] Manager CANNOT remove members
- [ ] Manager role is shown with green badge

#### 4.4 Viewer Role
- [ ] Viewer can view team page
- [ ] Viewer CANNOT invite team members
- [ ] Viewer CANNOT change roles
- [ ] Viewer CANNOT remove members
- [ ] Viewer role is shown with gray badge

---

### 5. Team Invitations

#### 5.1 Creating Invitations
- [ ] Owners and admins see "Invite Team Member" button
- [ ] Managers and viewers do NOT see invite button
- [ ] Invitation form requires email and role
- [ ] Cannot invite to "owner" role via UI
- [ ] Invitation email is sent via Loops.so
- [ ] Invitation appears in "Pending Invitations" list
- [ ] Invitation expires after 7 days

#### 5.2 Accepting Invitations - Existing Users
- [ ] User clicks invitation link in email
- [ ] If signed in, sees simple "Accept" button with advertiser info
- [ ] Click "Accept" → added to advertiser with correct role
- [ ] Redirected to advertiser dashboard
- [ ] If not signed in, can click "Sign in to accept"
- [ ] After sign in, automatically redirected back to acceptance page

#### 5.3 Accepting Invitations - New Users
- [ ] User clicks invitation link in email
- [ ] Sees signup form with email pre-filled (disabled)
- [ ] Must provide: first name, last name, password
- [ ] Account is created without email verification step
- [ ] Automatically added to advertiser with correct role
- [ ] Automatically signed in and redirected to advertiser dashboard

#### 5.4 Invalid Invitations
- [ ] Expired invitation shows "Invitation No Longer Valid" page
- [ ] Cancelled invitation shows "Invitation No Longer Valid" page
- [ ] Already-accepted invitation shows "Invitation No Longer Valid" page
- [ ] Invalid page shows helpful message and next steps
- [ ] Does NOT reveal specific reason (security)

#### 5.5 Managing Invitations
- [ ] Owners/admins can resend pending invitations
- [ ] Owners/admins can cancel pending invitations
- [ ] Managers/viewers cannot manage invitations
- [ ] After cancellation, invitation is removed from list
- [ ] Resend updates expiry to 7 days from now

---

### 6. Data Isolation & Security

#### 6.1 Advertiser Data Isolation
- [ ] User A creates invitation in Advertiser X
- [ ] User B (in Advertiser Y) cannot see invitation from Advertiser X
- [ ] User B cannot access team page of Advertiser X (silently redirected)
- [ ] Manually crafted URLs to other advertisers are blocked
- [ ] No error messages reveal existence of other advertisers

#### 6.2 Cross-Advertiser Attack Prevention
- [ ] Try to resend invitation from another advertiser → silent redirect
- [ ] Try to cancel invitation from another advertiser → silent redirect
- [ ] Try to change role of member from another advertiser → silent redirect
- [ ] Try to remove member from another advertiser → silent redirect
- [ ] Malformed URLs with invalid IDs → silent redirect (no routing error)

#### 6.3 Model-Level Scoping
- [ ] `Invitation.all` only returns invitations for current advertiser
- [ ] `Invitation.find(other_advertiser_invitation_id)` returns nothing
- [ ] Queries are automatically scoped even if controller has bug
- [ ] `Current.advertiser` is set correctly on all advertiser pages

#### 6.4 Removed User Access
- [ ] User is removed from advertiser
- [ ] User tries to access advertiser → silently redirected to advertisers index
- [ ] No error message (security by obscurity)
- [ ] User can still access other advertisers they belong to

---

### 7. Role Change & Member Management

#### 7.1 Changing Roles (Owner)
- [ ] Owner sees dropdown for all team members except themselves
- [ ] Dropdown shows: Admin, Manager, Viewer (no Owner option)
- [ ] Changing role updates immediately (auto-submit)
- [ ] Success message confirms change
- [ ] Owner cannot change their own role

#### 7.2 Changing Roles (Admin)
- [ ] Admin sees dropdown for manager/viewer members only
- [ ] Admin does NOT see dropdown for owner
- [ ] Admin does NOT see dropdown for other admins
- [ ] Dropdown shows: Admin, Manager, Viewer
- [ ] Changing role updates immediately
- [ ] Success message confirms change

#### 7.3 Removing Members (Owner)
- [ ] Owner can remove any member except themselves
- [ ] Owner cannot remove themselves
- [ ] "Remove" button shows for all members except owner
- [ ] Confirmation prompt appears before removal
- [ ] After removal, member is removed from list
- [ ] Success message confirms removal

#### 7.4 Removing Members (Admin)
- [ ] Admin can remove managers and viewers
- [ ] Admin CANNOT remove owner (no remove button shown)
- [ ] Admin CANNOT remove other admins (no remove button shown)
- [ ] Confirmation prompt appears before removal
- [ ] Success message confirms removal

---

### 8. Edge Cases & Error Handling

#### 8.1 Multiple Advertisers
- [ ] User belongs to 3+ advertisers
- [ ] Can switch between all advertisers freely
- [ ] Data is correctly isolated for each
- [ ] Navigation works smoothly

#### 8.2 Same Email Invited to Multiple Advertisers
- [ ] User invited to Advertiser A and Advertiser B
- [ ] Accepts invitation to Advertiser A first
- [ ] Can still accept invitation to Advertiser B
- [ ] No "email already taken" error
- [ ] User sees both advertisers in their list

#### 8.3 Invitation Link Reuse
- [ ] User accepts invitation
- [ ] User clicks the same link again → "No Longer Valid" page
- [ ] Cannot use same invitation twice

#### 8.4 Session Handling
- [ ] User invited to advertiser while not signed in
- [ ] Clicks "Sign in to accept" with invitation token
- [ ] Signs in
- [ ] Automatically redirected to invitation acceptance
- [ ] Token persists through sign-in flow

---

## Testing Checklist

Run through these scenarios in this order:

### Phase 1: Basic Auth
1. Sign up new user → verify email → create first advertiser
2. Sign out → sign in → verify redirect to dashboard
3. Create second advertiser → verify both show in list

### Phase 2: Invitations
4. Invite user to Advertiser A (new user flow)
5. Invite existing user to Advertiser B (existing user flow)
6. Test resend and cancel functionality
7. Test expired/cancelled invitation pages

### Phase 3: Roles & Permissions
8. As owner: change roles, remove members
9. As admin: try to change roles (should be limited)
10. As manager: verify no team management options
11. As viewer: verify no team management options

### Phase 4: Data Isolation
12. Create data in Advertiser A
13. Switch to Advertiser B
14. Verify cannot see Advertiser A's data
15. Try cross-advertiser URLs → verify silent redirects

### Phase 5: Edge Cases
16. Test same email invited to multiple advertisers
17. Test removed user trying to access advertiser
18. Test malformed URLs and invalid tokens

---

## Critical Security Tests

These MUST pass for production:

### 🔒 Test 1: Cross-Advertiser Data Access
```
Given: User is member of Advertiser A
And: Advertiser B exists with invitation ID 123
When: User tries to access /advertisers/advertiser-a/invitations/123/resend
Then: User is silently redirected (no error, no access)
```

### 🔒 Test 2: Model-Level Scoping
```
Given: Current.advertiser is set to Advertiser A
When: Code runs Invitation.all
Then: Only Advertiser A's invitations are returned
And: Advertiser B's invitations are never visible
```

### 🔒 Test 3: Removed User Access
```
Given: User was member of Advertiser A
And: User is removed from Advertiser A
When: User tries to access any Advertiser A page
Then: User is silently redirected to advertisers index
And: No error message is shown
```

### 🔒 Test 4: Role Permission Enforcement
```
Given: User is Admin in Advertiser A
When: User tries to change Owner's role
Then: Request is blocked
And: Owner role remains unchanged
```

---

## Notes

- **Security by Obscurity**: We intentionally don't show error messages that reveal whether resources exist
- **Silent Redirects**: Invalid access attempts redirect without explanation to prevent information leakage
- **Two-Layer Defense**: Both controller and model layers enforce security independently
- **Automatic Scoping**: All queries for scoped models are automatically filtered by `Current.advertiser`

---

## Future Models

When adding new models that need multitenancy:

```ruby
class Campaign < ApplicationRecord
  include AdvertiserScoped  # One line enables full multitenancy!
end
```

All queries will automatically be scoped to the current advertiser.

