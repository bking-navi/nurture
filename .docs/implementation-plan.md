# Nurture Marketing Platform - Implementation Plan

## Overview

This document outlines the user-centered implementation plan for the Nurture marketing platform. For complete technical specifications, database schemas, security requirements, and detailed implementation details, see [nurture-auth-requirements.md](./nurture-auth-requirements.md).

## Philosophy

This plan breaks down the work into **user-centered feature slices** that deliver complete value to users. Each slice is a full front-to-back implementation that can be released independently and demoed to stakeholders. No technical debt or half-finished features.

## Database Strategy

**Local Development:**
- SQLite for speed and simplicity
- All migrations work on SQLite
- Easy local setup

**Production:**
- PostgreSQL for performance and features
- Same migration files work on both databases
- Render provides managed PostgreSQL

## Feature Slices

### Slice 1: "I can create an account and verify my email"
**User Story:** As a new user, I want to create an account and verify my email so I can access the platform.

**What the user experiences:**
- Clean signup form with email/password/name fields
- Email verification sent to their inbox
- Click verification link → account activated
- Can now log in and out

**Technical scope:**
- Devise setup with custom password requirements (see [requirements](./nurture-auth-requirements.md#password-requirements))
- User model with email verification
- Loops.so integration for verification emails (see [email templates](./nurture-auth-requirements.md#transactional-email-templates))
- Basic login/logout functionality
- SQLite for dev, PostgreSQL for production

**Release criteria:**
- User can sign up with valid email
- Verification email arrives and works
- User can log in after verification
- Password requirements enforced (12+ chars, complexity)

**References:**
- [User model specs](./nurture-auth-requirements.md#user)
- [Registration flow details](./nurture-auth-requirements.md#registration-flow-multi-step)
- [Email verification template](./nurture-auth-requirements.md#1-email-verification-after-step-1-registration)

---

### Slice 2: "I can create my business and become the owner"
**User Story:** As a verified user, I want to create my business profile so I can start using the platform for my company.

**What the user experiences:**
- After email verification, guided to create business
- Form asks for business name, address, website
- Business gets a clean URL slug (e.g., `/advertisers/acme-corp`)
- User becomes the owner of their business
- Redirected to their business dashboard

**Technical scope:**
- Advertiser model with address/website fields
- AdvertiserMembership model (user → advertiser relationship)
- Two-step registration flow (account → business)
- Slug generation and validation
- Basic dashboard view

**Release criteria:**
- User can create business after email verification
- Business gets unique, URL-friendly slug
- User becomes owner automatically
- Can access business dashboard

**References:**
- [Advertiser model specs](./nurture-auth-requirements.md#advertiser)
- [AdvertiserMembership model specs](./nurture-auth-requirements.md#advertisermembership)
- [Step 2 registration details](./nurture-auth-requirements.md#step-2-advertiser-creation)
- [Database schema](./nurture-auth-requirements.md#database-schema)

---

### Slice 3: "I can invite team members to my business"
**User Story:** As a business owner, I want to invite team members so we can collaborate on marketing campaigns.

**What the user experiences:**
- Team management page showing current members
- "Invite Team Member" button opens clean form
- Select role (Admin, Manager, Viewer) for invitee
- Invitation email sent with clear call-to-action
- Can see pending invitations and resend if needed

**Technical scope:**
- Team management interface
- Invitation system with role selection
- Invitation emails via Loops.so
- Pending invitations tracking
- Role-based UI (only owners/admins can invite)

**Release criteria:**
- Owner can invite team members
- Invitation emails work for both existing and new users
- Can see pending invitations
- Role selection works properly

**References:**
- [Role permissions matrix](./nurture-auth-requirements.md#role-permissions-matrix)
- [Invitation flow details](./nurture-auth-requirements.md#invitation-flow)
- [Team invitation email template](./nurture-auth-requirements.md#2-team-invitation)
- [Team management UI specs](./nurture-auth-requirements.md#team-management-page)

---

### Slice 4: "I can accept invitations and join businesses"
**User Story:** As someone invited to a business, I want to easily accept the invitation and start collaborating.

**What the user experiences:**
- Click invitation link in email
- If existing user: simple "Accept" confirmation
- If new user: guided setup (password → profile → accept)
- Automatically logged in and redirected to business dashboard
- Clear success message about joining the business

**Technical scope:**
- Invitation acceptance flows (existing vs new users)
- Token-based invitation system
- New user onboarding flow
- Automatic login after acceptance
- Membership status tracking

**Release criteria:**
- Existing users can accept invitations easily
- New users get guided setup process
- Invitations expire after 7 days
- Users are properly added to business

**References:**
- [Invitation acceptance flows](./nurture-auth-requirements.md#invitation-acceptance---existing-users)
- [New user multi-step setup](./nurture-auth-requirements.md#invitation-acceptance---new-users-multi-step)
- [Token security requirements](./nurture-auth-requirements.md#token-security)
- [Business rules for invitations](./nurture-auth-requirements.md#business-rules)

---

### Slice 5: "I can switch between my businesses"
**User Story:** As a user who belongs to multiple businesses, I want to easily switch between them so I can work on different projects.

**What the user experiences:**
- Clean business switcher in navigation
- Shows all businesses they belong to with their role
- Click to switch → immediate context change
- URL updates to show current business
- Navigation shows current business name

**Technical scope:**
- Current context system (Current.advertiser)
- Business switcher UI component
- Path-based routing with business slugs
- Context switching logic
- Navigation updates

**Release criteria:**
- Users with multiple businesses see switcher
- Context switching works seamlessly
- URLs reflect current business
- Navigation shows current context

**References:**
- [Context management system](./nurture-auth-requirements.md#context-management-path-based-routing)
- [Current context storage](./nurture-auth-requirements.md#current-context-storage)
- [Advertiser switcher UI](./nurture-auth-requirements.md#advertiser-switcher)
- [URL structure](./nurture-auth-requirements.md#url-structure)

---

### Slice 6: "I can manage my team and their roles"
**User Story:** As a business owner/admin, I want to manage team members and their permissions so I can control access appropriately.

**What the user experiences:**
- Team page showing all members with roles
- Change role dropdown for each member
- Remove member functionality
- Transfer ownership option
- Clear role badges and permissions

**Technical scope:**
- Team management interface
- Role change functionality
- Member removal with proper validation
- Ownership transfer flow
- Permission enforcement

**Release criteria:**
- Owners can change any role except their own
- Admins can change roles except owner
- Can remove members (with proper restrictions)
- Ownership transfer works
- Role permissions are enforced

**References:**
- [Role permissions matrix](./nurture-auth-requirements.md#role-permissions-matrix)
- [Team management UI](./nurture-auth-requirements.md#team-management-page)
- [Business rules for team management](./nurture-auth-requirements.md#business-rules)
- [Authorization patterns](./nurture-auth-requirements.md#authorization)

---

### Slice 7: "My business data is completely private"
**User Story:** As a business owner, I want to be confident that my data is completely isolated from other businesses so I can trust the platform with sensitive information.

**What the user experiences:**
- Cannot see other businesses' data even with direct URLs
- Switching businesses shows completely different data
- No accidental cross-business access
- Clear error messages for unauthorized access

**Technical scope:**
- AdvertiserScoped concern for all business data
- Default scoping on all tenant models
- Security testing and validation
- Proper error handling for unauthorized access
- Data isolation verification

**Release criteria:**
- Impossible to access other businesses' data
- All queries automatically scoped to current business
- Security tests pass
- Clear error messages for unauthorized access

**References:**
- [Data scoping requirements](./nurture-auth-requirements.md#data-scoping-critical-security)
- [Security requirements](./nurture-auth-requirements.md#security-requirements)
- [Data isolation testing](./nurture-auth-requirements.md#security-testing)
- [Models that need scoping](./nurture-auth-requirements.md#models-that-need-scoping)

---

## Implementation Order

1. **Slice 1** → Users can sign up and verify emails
2. **Slice 2** → Users can create businesses and become owners  
3. **Slice 3** → Owners can invite team members
4. **Slice 4** → Invited users can accept and join
5. **Slice 5** → Users can switch between businesses
6. **Slice 6** → Team management is fully functional
7. **Slice 7** → Security and data isolation is bulletproof

## Success Criteria

Each slice delivers immediate value to users and can be demoed to stakeholders. No technical debt or half-finished features.

**Overall success:** A production-ready auth and multitenancy system that can be deployed to Render and used by real users for team collaboration on marketing campaigns.

## Next Steps

Start with Slice 1 (account creation and email verification) by:
1. Adding required gems to Gemfile
2. Setting up Devise with custom configuration
3. Creating User model and migrations
4. Implementing email verification flow
5. Testing the complete user journey

For detailed technical specifications, security requirements, database schemas, and implementation details, refer to [nurture-auth-requirements.md](./nurture-auth-requirements.md).
