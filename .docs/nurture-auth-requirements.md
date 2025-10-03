# Marketing Platform - Auth & Multitenancy Requirements

## Overview

Building a direct mail marketing platform (similar to Klaviyo) with focus on getting auth and multitenancy rock-solid first. This will be built with Rails 8, deployed to Render, using Devise for authentication and path-based routing for tenant isolation.

## Tech Stack

- Rails 8.0.x
- PostgreSQL
- Sidekiq (background jobs)
- Redis (job queue)
- Devise (authentication)
- Shopify API gem (future phase)
- Loops.so (transactional emails)
- Tailwind CSS
- Hotwire/Turbo
- Deploy: Render

---

## Core Entities

### User

**Purpose:** The person who logs in. Can belong to multiple Advertisers with different roles.

**Attributes:**
- email (unique, required)
- encrypted_password (Devise)
- first_name (required)
- last_name (required)
- email_verified (boolean, default false)
- email_verified_at (timestamp)
- last_sign_in_at (Devise trackable)
- last_sign_in_ip (Devise trackable)
- created_at, updated_at

**Relationships:**
- has_many advertiser_memberships
- has_many advertisers, through: advertiser_memberships

**Methods needed:**
- display_name → "First Last"
- initials → "FL" for avatars
- admin_of?(advertiser) → checks if owner or admin role
- can_manage_team?(advertiser) → checks if has permission to invite/remove users
- has_access_to?(advertiser) → checks if membership exists

**Validations:**
- Email: valid format, unique, max 255 chars
- First/last name: 1-50 characters, required
- Password: min 12 characters (Devise config), must include uppercase, lowercase, number

---

### Advertiser

**Purpose:** The tenant. Represents a business/brand that owns contacts, campaigns, etc.

**Attributes:**
- name (required, 2-100 chars)
- slug (unique, auto-generated from name, lowercase alphanumeric + hyphens)
- street_address (required)
- city (required)
- state (required)
- postal_code (required)
- country (required, validate against ISO list)
- website_url (required, valid URL format with protocol)
- shopify_domain (optional, for future Shopify integration)
- shopify_access_token_encrypted (optional)
- settings (JSONB, default {})
- organization_id (nullable foreign key, for future use, don't implement yet)
- created_at, updated_at

**Settings JSONB structure:**
```
{
  timezone: "America/New_York",
  currency: "USD",
  email_from_name: "Company Name",
  email_reply_to: "support@company.com",
  shopify_sync_frequency: "hourly"
}
```

**Relationships:**
- has_many advertiser_memberships, dependent: destroy
- has_many users, through: advertiser_memberships
- has_many contacts, dependent: destroy
- has_many campaigns, dependent: destroy
- has_many orders, dependent: destroy
- has_many products, dependent: destroy
- belongs_to organization, optional: true (future)

**Methods needed:**
- owner → returns User with owner role
- generate_slug → creates URL-friendly slug from name
- address_formatted → returns multi-line formatted address string

**Validations:**
- Name: 2-100 characters, required
- Slug: unique, lowercase, alphanumeric + hyphens only, auto-generated
- All address fields: required, reasonable length limits
- Website URL: valid format, must include http/https
- Country: valid ISO country code

---

### AdvertiserMembership

**Purpose:** Join table linking Users to Advertisers with roles and invitation tracking.

**Attributes:**
- user_id (foreign key, required)
- advertiser_id (foreign key, required)
- role (enum: owner, admin, manager, viewer)
- status (enum: pending, accepted, declined)
- invited_at (timestamp, when invitation sent)
- accepted_at (timestamp, when user accepted)
- declined_at (timestamp, if user rejected)
- created_at, updated_at

**Relationships:**
- belongs_to user
- belongs_to advertiser

**Methods needed:**
- pending? → status is pending
- accepted? → status is accepted
- resend_invitation → regenerates token, sends email again
- days_until_expiry → for UI warning messages
- generate_token_for(:invitation) → secure signed token

**Validations:**
- user_id + advertiser_id: unique combination
- Only one owner per advertiser
- Role required
- Cannot create duplicate memberships

**Business rules:**
- Only owner can transfer ownership
- Cannot remove yourself if you're only owner
- Role changes: only owner can make someone else owner
- Invitations expire after 7 days
- Tokens are single-use (mark status as accepted after first use)

---

## Role Permissions Matrix

### Owner
- Everything an Admin can do
- Transfer ownership to another admin
- Delete the Advertiser account
- Cannot be removed (only transferred)
- Only one per Advertiser

### Admin
- Manage team: invite, remove users, change roles (except cannot create/modify owner)
- Full access to all features (campaigns, contacts, segments)
- Modify Advertiser settings
- Connect/disconnect Shopify
- View all analytics

### Manager
- Create, edit, delete campaigns
- Create, edit, delete segments
- View all contacts and analytics
- Cannot manage team
- Cannot modify settings

### Viewer
- Read-only access to everything
- Can view campaigns, segments, contacts, analytics
- Cannot create, edit, or delete anything
- Cannot manage team or settings

---

## Registration Flow (Multi-Step)

### Step 1: User Account Creation

**Route:** `/signup/account`

**Form fields:**
- Email
- Password
- Password confirmation
- First name
- Last name

**Process:**
1. Validate all fields
2. Create User with Devise
3. Send email verification via Loops
4. Store pending_user_id in session
5. Redirect to "check your email" page
6. User clicks verification link in email
7. Mark email_verified=true, email_verified_at=now
8. Redirect to Step 2

**Validations:**
- Email format, uniqueness
- Password strength (12+ chars, uppercase, lowercase, number)
- Names required

### Step 2: Advertiser Creation

**Route:** `/signup/advertiser`

**Protected by:** Must have pending_user_id in session or redirect to Step 1

**Form fields:**
- Advertiser name
- Street address
- City
- State/Province
- Postal code
- Country (dropdown)
- Website URL

**Process:**
1. Validate all fields
2. Create Advertiser with auto-generated slug
3. Create AdvertiserMembership with:
   - user: current_user
   - role: owner
   - status: accepted
   - accepted_at: now
4. Clear pending_user_id from session
5. Log user in (set Devise session)
6. Redirect to advertiser dashboard or onboarding flow

**Validations:**
- All address fields required
- Website URL format (must include http/https)
- Country code valid
- Slug uniqueness (auto-handle conflicts by appending -2, -3, etc.)

**Benefits of two-step:**
- User can verify email before committing to full setup
- If they abandon, you have their email for re-engagement
- Separates identity from business entity
- Clean place to add "what kind of business" questions later

---

## Invitation Flow

### Admin/Owner Invites Someone

**Route:** `/advertisers/:slug/team/invitations/new`

**Protected by:** require_role(:owner, :admin)

**Form fields:**
- Email address
- Role selector (admin, manager, viewer - owner not selectable)

**Process:**
1. Check if User exists with that email
2. If no User exists:
   - Create User with email, random password
   - Set email_verified=false
3. If User exists: use existing User
4. Create AdvertiserMembership with:
   - user: found/created user
   - advertiser: current_advertiser
   - role: selected role
   - status: pending
   - invited_at: now
5. Generate secure invitation token (valid 7 days)
6. Send invitation email via Loops with token link
7. Show success message: "Invitation sent to [email]"

### Invitation Acceptance - Existing Users

**Route:** `/invitations/:token`

**Process:**
1. Decode and validate token
2. Check token not expired (< 7 days old)
3. Check membership status is pending
4. If user logged in:
   - Show "Accept invitation to [Advertiser]?" confirmation page
   - Button to accept
5. If user not logged in:
   - Redirect to login with return_to parameter
   - After login, redirect back to invitation
6. On accept:
   - Update membership: status=accepted, accepted_at=now
   - Redirect to advertiser dashboard
   - Show success: "You're now part of [Advertiser]!"

### Invitation Acceptance - New Users (Multi-Step)

**Step 1: Password Setup**

**Route:** `/invitations/:token/setup`

**Form fields:**
- Password
- Password confirmation

**Process:**
1. Validate token
2. Show welcome: "You've been invited to [Advertiser] as [Role]"
3. User sets password
4. Update User password
5. Store token in session
6. Redirect to Step 2

**Step 2: Profile Completion**

**Route:** `/invitations/:token/profile`

**Protected by:** Must have valid token in session

**Form fields:**
- First name
- Last name

**Process:**
1. Validate token from session
2. User enters name
3. Update User: first_name, last_name, email_verified=true, email_verified_at=now
4. Update membership: status=accepted, accepted_at=now
5. Log user in (set Devise session)
6. Clear token from session
7. Redirect to advertiser dashboard
8. Show success: "Welcome to [Advertiser]!"

**Benefits of multi-step for new users:**
- Gets name for proper display ("John Smith" not "john@example.com")
- Separates security (password) from identity (name)
- Can add "what's your role at the company?" later
- Better UX than cramming everything into one form

---

## Context Management (Path-Based Routing)

### URL Structure

**No subdomains used.** Everything is path-based:

```
yourapp.com/advertisers/:slug/dashboard
yourapp.com/advertisers/:slug/campaigns
yourapp.com/advertisers/:slug/campaigns/:id
yourapp.com/advertisers/:slug/contacts
yourapp.com/advertisers/:slug/segments
yourapp.com/advertisers/:slug/settings
yourapp.com/advertisers/:slug/team
```

**Future-proof for agencies/organizations:**
```
yourapp.com/agencies/:slug/dashboard
yourapp.com/agencies/:slug/clients
yourapp.com/organizations/:slug/advertisers
```

### Determining current_advertiser

**Priority order:**
1. Extract :slug from params[:slug] or params[:advertiser_slug]
2. Look up Advertiser.find_by(slug: slug)
3. Verify current_user has membership with that advertiser
4. Set Current.advertiser, Current.membership
5. If no advertiser found or no access: redirect to /advertisers (switcher)

**Implementation pattern:**
- ApplicationController before_action: set_current_advertiser
- Use Rails CurrentAttributes to store Current.advertiser, Current.user, Current.membership
- Makes context available everywhere without passing parameters

### Current Context Storage

Use ActiveSupport::CurrentAttributes:

```
class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :advertiser
  attribute :membership
end
```

Set in ApplicationController:
- Current.user = current_user (from Devise)
- Current.advertiser = found advertiser
- Current.membership = current_user's membership with advertiser

### Helper Methods Needed

**ApplicationController:**
- advertiser_path_for(resource) → generates /advertisers/:slug/resources/:id
- current_advertiser_path(path) → prefixes path with current advertiser slug
- require_role(*roles) → before_action to check permissions
- current_user_has_access? → checks if user can access current advertiser

**Usage example:**
```
# Instead of: advertiser_campaigns_path(@advertiser)
# Use: current_advertiser_path('campaigns')

# For specific resource:
# current_advertiser_path("campaigns/#{@campaign.id}")
```

### Benefits of Path-Based Routing

**Pros:**
- No subdomain DNS configuration needed
- No CORS issues
- Easier local development (just localhost:3000)
- Agency and Organization views at same level as Advertiser
- Can link between contexts easily
- Works perfectly in development, staging, production

**Cons (accepted):**
- Slightly longer URLs
- Slug must be in every link (solved with helper methods)

---

## Data Scoping (Critical Security)

### Automatic Tenant Scoping

**All tenant data must automatically scope to Current.advertiser:**

Create an AdvertiserScoped concern:
- Adds belongs_to :advertiser
- Adds validation: advertiser presence
- Adds default_scope { where(advertiser: Current.advertiser) if Current.advertiser }
- Include in: Contact, Order, Product, Campaign, Segment, etc.

**Effect:**
```
# All queries automatically scoped
Contact.all  # → Contact.where(advertiser: Current.advertiser)
Contact.find(123)  # → only finds if belongs to Current.advertiser
Campaign.create(name: "Summer Sale")  # → automatically sets advertiser_id

# Makes cross-tenant data access impossible
```

### Models That Need Scoping

- Contact (Shopify customers)
- Order (Shopify orders)
- Product (Shopify products)
- Campaign
- Segment
- CampaignSend
- Any future tenant-owned data

### Models That Don't Need Scoping

- User (shared across advertisers)
- Advertiser (the tenant itself)
- AdvertiserMembership (join table)
- Organization (future, parent of advertisers)
- Agency (future, separate entity)

### Security Testing

**Critical test cases:**
1. Cannot query another advertiser's contacts with direct ID
2. Cannot create data without advertiser_id set
3. Switching advertiser context changes query results
4. Default scope cannot be bypassed accidentally

---

## Advertiser Switcher

### For Users with Multiple Advertisers

**Show when:**
- User belongs to 2+ advertisers via memberships
- Display in navbar as dropdown
- Also accessible at /advertisers route

**Switcher UI includes:**
- List of all advertisers user has access to
- User's role badge next to each (Owner, Admin, Manager, Viewer)
- Highlight current advertiser
- Click to switch (changes session, redirects to that dashboard)
- "Create new advertiser" button at bottom

**For users with single advertiser:**
- Skip switcher
- Auto-select their one advertiser on login
- Still show advertiser name in navbar (not dropdown)

### Navigation Component

**Navbar should show:**
- Logo
- Current advertiser name (dropdown if >1 advertiser)
- Main navigation links (Dashboard, Campaigns, Contacts, etc.)
- User menu (Profile, Settings, Logout)

**Breadcrumbs:**
- Home > [Advertiser Name] > Current Section > Current Page
- Makes current context always visible
- Advertiser name in breadcrumb is clickable dropdown for switching

---

## Email Notifications via Loops.so

### Loops Integration

**Service class needed: LoopsClient**

Methods:
- send_transactional(email, template_id, variables)
- create_or_update_contact(email, properties) (for future use)

**Configuration:**
- Store LOOPS_API_KEY in Rails credentials
- API base URL: https://app.loops.so/api/v1
- Use HTTParty gem for requests

### Transactional Email Templates

**1. Email Verification** (after Step 1 registration)

**Template ID:** email_verification

**Trigger:** User completes Step 1

**Variables:**
- first_name
- verification_url

**Subject:** "Verify your email for [YourApp]"

**Content:**
- Welcome message
- CTA button: "Verify Email"
- Link takes to Step 2 after verification
- Expires in 24 hours

---

**2. Team Invitation**

**Template ID:** team_invitation

**Trigger:** AdvertiserMembership created with status=pending

**Variables:**
- inviter_name (Current.user.display_name)
- advertiser_name
- role (admin/manager/viewer)
- invitation_url
- is_new_user (boolean, to customize message)

**Subject:** "[Inviter] invited you to [Advertiser]"

**Content for existing users:**
- "[Inviter] has invited you to join [Advertiser] as a [Role]"
- CTA button: "Accept Invitation"
- Link to /invitations/:token

**Content for new users:**
- "You've been invited to [Advertiser]"
- Explains they'll create an account
- CTA button: "Get Started"
- Link to /invitations/:token/setup

---

**3. Password Reset** (Devise default, customize with Loops)

**Template ID:** password_reset

**Trigger:** User requests password reset

**Variables:**
- first_name
- reset_url

**Subject:** "Reset your password"

**Content:**
- "We received a request to reset your password"
- CTA button: "Reset Password"
- "If you didn't request this, ignore this email"
- Expires in 15 minutes

---

### Future Email Templates

**Campaign Scheduled Confirmation:**
- Trigger: Campaign status changes to scheduled
- Notifies campaign creator
- Shows scheduled time, target segment count

**Segment Processing Complete:**
- Trigger: Large segment finishes calculating
- Shows final contact count
- Link to view segment

**Shopify Sync Errors:**
- Trigger: Shopify sync job fails 3+ times
- Notifies advertiser owner/admins
- Shows error details, suggests fixes

**Weekly Summary Report:**
- Trigger: Scheduled weekly (future)
- Campaigns sent, contacts added, engagement metrics
- Link to full analytics dashboard

---

## Routes Structure

### Public Routes (No Authentication)

```
GET  /signup/account              → Step 1: user account creation form
POST /signup/account              → Create user, send verification
GET  /signup/advertiser           → Step 2: advertiser creation form
POST /signup/advertiser           → Create advertiser, make user owner

GET  /login                       → Devise session new
POST /login                       → Devise session create
DELETE /logout                    → Devise session destroy

GET  /password/reset              → Devise password reset request
POST /password/reset              → Send reset email
GET  /password/reset/:token/edit  → Reset password form
PUT  /password/reset              → Update password

GET  /verify_email/:token         → Email verification callback

GET  /invitations/:token          → Show invitation details
GET  /invitations/:token/setup    → Step 1 for new users (password)
POST /invitations/:token/setup    → Save password, go to Step 2
GET  /invitations/:token/profile  → Step 2 for new users (name)
POST /invitations/:token/profile  → Complete setup, log in
POST /invitations/:token/accept   → Accept invitation (existing users)
```

### Authenticated Routes

**Advertiser Management:**
```
GET  /advertisers                 → List all user's advertisers (switcher)
GET  /advertisers/new             → Create additional advertiser form
POST /advertisers                 → Create new advertiser
```

### Advertiser-Scoped Routes

All nested under `/advertisers/:slug/`

```
GET /advertisers/:slug/dashboard  → Main dashboard

# Team Management (owner/admin only)
GET  /advertisers/:slug/team      → List members
GET  /advertisers/:slug/team/invitations/new  → Invite form
POST /advertisers/:slug/team/invitations      → Send invitation
DELETE /advertisers/:slug/team/members/:id    → Remove member
PATCH /advertisers/:slug/team/members/:id     → Change role

# Settings (owner/admin only)
GET  /advertisers/:slug/settings              → Advertiser settings form
PATCH /advertisers/:slug/settings             → Update settings

# Future routes for Phase 2+
# GET  /advertisers/:slug/campaigns
# GET  /advertisers/:slug/contacts
# GET  /advertisers/:slug/segments
# GET  /advertisers/:slug/analytics
```

---

## UI Components

### Role Badge Component

**Display format:**
- Owner: Gold/yellow badge with crown icon
- Admin: Blue badge
- Manager: Green badge
- Viewer: Gray badge

**Used in:**
- Team management page (next to each member)
- Advertiser switcher (next to each advertiser)
- User profile header

### Advertiser Switcher Dropdown

**Structure:**
```
[Current Advertiser Name ▼]
  ├─ Acme Corp (Owner) ✓
  ├─ Beta Inc (Admin)
  ├─ Gamma LLC (Manager)
  ├─────────────────────
  └─ + Create New Advertiser
```

**Behavior:**
- Checkmark on current advertiser
- Click advertiser: switches context, redirects to that dashboard
- Hover shows full advertiser name if truncated

### Team Management Page

**Sections:**

**Active Members Table:**
- Columns: Name, Email, Role, Actions
- Sort by role (owner first), then name
- Actions: Change Role dropdown (owner/admin only), Remove button
- Owner cannot be removed
- Cannot remove yourself if you're only owner

**Pending Invitations Table:**
- Columns: Email, Role, Invited By, Invited At, Actions
- Actions: Resend, Revoke
- Shows "Expires in X days" warning

**Invite Button:**
- Only visible to owner/admin
- Opens modal or inline form
- Email input + role selector

### Empty States

**No advertisers yet:**
```
[Icon]
You're not part of any advertisers yet
Create your first advertiser to get started
[Create Advertiser Button]
```

**No team members yet:**
```
[Icon]
Build your team
Invite team members to collaborate on campaigns
[Invite Team Member Button]
```

**No pending invitations:**
```
All invitations have been accepted!
[Invite Another Member Button]
```

### Loading States

**During advertiser creation:**
- Show spinner on submit button
- Disable form fields
- "Creating your advertiser..."

**During invitation send:**
- Show spinner on send button
- "Sending invitation..."
- Success: show toast notification

**During context switch:**
- Brief loading overlay
- "Switching to [Advertiser]..."

### Error Handling & Messages

**Invalid invitation token:**
```
This invitation link is invalid or expired.
Please contact [inviter_email] for a new invitation.
```

**Advertiser slug conflict:**
- Auto-suggest alternatives: acme-2, acme-corp, acme-inc
- Show: "The name 'Acme' is taken. We've suggested 'acme-2'"

**Email already in use:**
```
This email is already registered.
[Log In Instead] button
```

**Insufficient permissions:**
```
You don't have permission to perform this action.
Contact your advertiser owner or admin for access.
```

### Success Messages

**After Step 2 completion:**
```
Welcome to [YourApp]!
Your advertiser "[Name]" is ready to go.
```

**After invitation sent:**
```
Invitation sent to [email]
They'll receive it within a few minutes.
```

**After accepting invitation:**
```
You're now part of [Advertiser]!
```

**After removing team member:**
```
[Name] has been removed from [Advertiser]
```

---

## Database Schema

### Users Table

```
id (primary key)
email (string, unique, indexed)
encrypted_password (string)
first_name (string)
last_name (string)
email_verified (boolean, default: false)
email_verified_at (timestamp)
reset_password_token (string, unique, indexed) - Devise
reset_password_sent_at (timestamp) - Devise
remember_created_at (timestamp) - Devise
sign_in_count (integer, default: 0) - Devise trackable
current_sign_in_at (timestamp) - Devise trackable
last_sign_in_at (timestamp) - Devise trackable
current_sign_in_ip (inet) - Devise trackable
last_sign_in_ip (inet) - Devise trackable
created_at (timestamp)
updated_at (timestamp)
```

### Advertisers Table

```
id (primary key)
name (string)
slug (string, unique, indexed)
street_address (string)
city (string)
state (string)
postal_code (string)
country (string)
website_url (string)
shopify_domain (string, nullable)
shopify_access_token_encrypted (text, nullable)
settings (jsonb, default: {})
organization_id (foreign key, nullable, indexed) - future use
created_at (timestamp)
updated_at (timestamp)
```

### Advertiser Memberships Table

```
id (primary key)
user_id (foreign key, indexed)
advertiser_id (foreign key, indexed)
role (integer) - enum: 0=owner, 1=admin, 2=manager, 3=viewer
status (integer) - enum: 0=pending, 1=accepted, 2=declined
invited_at (timestamp)
accepted_at (timestamp)
declined_at (timestamp)
created_at (timestamp)
updated_at (timestamp)

Composite unique index on (user_id, advertiser_id)
```

### Database Indices

**Critical for performance:**

```
users.email - unique index
advertisers.slug - unique index
advertiser_memberships (user_id, advertiser_id) - composite unique index
advertiser_memberships.advertiser_id - index for joins
advertiser_memberships.status - index for filtering pending invitations
```

**Future indices (when adding tenant data):**
```
contacts.advertiser_id
campaigns.advertiser_id
orders.advertiser_id
All tenant-scoped data needs advertiser_id indexed
```

---

## Security Requirements

### Authentication (Devise Handles)

- Password hashing with bcrypt
- Session management
- CSRF protection (Rails default)
- Secure password reset tokens
- Remember me functionality

### Password Requirements

**Update Devise configuration:**
- Minimum 12 characters (change from default 6)
- Must include: uppercase letter, lowercase letter, number
- Cannot be in common password list (Devise blocklist)
- Cannot be same as email address
- Use zxcvbn gem for password strength checking

### Authorization

**Every controller action must verify:**
1. User is authenticated (Devise before_action)
2. User has membership with current_advertiser
3. User's role has permission for the action

**Pattern:**
- ApplicationController: before_action :set_current_advertiser
- Specific controllers: before_action -> { require_role(:admin, :owner) }

### Token Security

**Invitation tokens:**
- Signed/encrypted, cannot be forged
- Expire after 7 days
- Single-use only (check status != pending after first use)
- Admin can revoke by deleting membership
- Generate with: membership.generate_token_for(:invitation)

**Email verification tokens:**
- Signed/encrypted
- Expire after 24 hours
- Single-use
- Generate with: user.generate_token_for(:email_verification)

**Password reset tokens:**
- Devise handles this
- Expire after 15 minutes (configure in Devise)
- Single-use

### Data Isolation

**Critical security rule: No cross-tenant data access**

Implementation:
- All tenant data uses AdvertiserScoped concern
- Default scope filters by Current.advertiser
- Impossible to query another advertiser's data even with direct ID
- Test thoroughly: try to access /advertisers/A/campaigns/123 where 123 belongs to advertiser B

**Security test cases:**
1. Direct ID access to another tenant's resource → 404 or access denied
2. API calls with another tenant's IDs → rejected
3. Bulk queries don't leak cross-tenant data
4. Switching advertiser context changes query results immediately

### Session Security

**Configuration:**
- Expire sessions after 2 weeks of inactivity
- Use secure cookies (Rails config: secure: true in production)
- HttpOnly cookies (prevent XSS access)
- SameSite: :lax (CSRF protection)

**Sensitive actions require re-authentication:**
- Transferring ownership
- Deleting advertiser
- Removing team members
- Changing Shopify credentials

Track:
- last_sign_in_at
- last_sign_in_ip
- Use Devise trackable module

### Rate Limiting (rack-attack gem)

**Protect against brute force:**

```
Login attempts: 5 per IP per 20 minutes
Signup attempts: 3 per IP per hour
Password reset requests: 3 per email per hour
Invitation sends: 10 per advertiser per hour
API calls (future): 100 per user per minute
```

**Response:**
- Return 429 Too Many Requests
- Show friendly error: "Too many attempts. Try again in X minutes."
- Log suspicious activity

### SQL Injection Prevention

**Rules:**
- Always use ActiveRecord query interface
- Never use raw SQL with user input
- If raw SQL needed, use parameterized queries
- Validate/sanitize all user input

**Example of safe query:**
```
# Good
Contact.where(email: params[:email])

# Bad - DON'T DO THIS
Contact.where("email = '#{params[:email]}'")
```

### XSS Prevention

**Rails defaults protect against XSS:**
- ERB escapes HTML by default
- Use raw/html_safe only when necessary
- Sanitize user-generated content
- Content Security Policy headers configured

---

## Configuration & Secrets

### Environment Variables

**Required for all environments:**
```
DATABASE_URL - Render provides
REDIS_URL - Render provides
RAILS_MASTER_KEY - for credentials file
SECRET_KEY_BASE - Rails generates
```

**Required for production:**
```
LOOPS_API_KEY - transactional emails
RACK_ENV=production
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true - for Render
RAILS_LOG_TO_STDOUT=true - for Render
```

**Future (Phase 2+):**
```
SHOPIFY_API_KEY
SHOPIFY_API_SECRET
SNOWFLAKE_* - connection details
```

### Rails Credentials

**Store sensitive data in encrypted credentials:**

```bash
rails credentials:edit
```

**Structure:**
```yaml
loops:
  api_key: your_loops_api_key

devise:
  secret_key: auto_generated

# Future:
shopify:
  api_key: xxx
  api_secret: xxx
```

### Devise Configuration

**config/initializers/devise.rb changes:**

```
config.password_length = 12..128 (change from default 6..128)
config.expire_password_after = 90.days (optional, force periodic resets)
config.reconfirmable = true (require re-verification on email change)
config.paranoid = true (don't reveal if email exists on password reset)
```

---

## Deployment (Render)

### Services to Create

**1. Web Service**
- Name: marketing-platform-web
- Environment: Ruby
- Build Command: `bundle install && rails assets:precompile && rails db:migrate`
- Start Command: `bundle exec puma -C config/puma.rb`
- Instance Type: Starter (can upgrade later)
- Auto-Deploy: Yes (on main branch)

**2. PostgreSQL Database**
- Name: marketing-platform-db
- Plan: Starter (can upgrade later)
- Automatically linked to web service via DATABASE_URL

**3. Redis Instance**
- Name: marketing-platform-redis
- Plan: Starter
- Automatically linked via REDIS_URL

**4. Background Worker**
- Name: marketing-platform-worker
- Environment: Ruby
- Build Command: `bundle install`
- Start Command: `bundle exec sidekiq`
- Instance Type: Starter
- Auto-Deploy: Yes
- Uses same DATABASE_URL and REDIS_URL as web service

### Health Check Endpoint

**Create route for Render health checks:**

```
GET /health → returns 200 OK with { status: "ok" }
```

Render pings this to verify deployment success and app health.

### Environment Variables Setup in Render

**Set these in Render dashboard for web service:**
- RAILS_MASTER_KEY (copy from config/master.key)
- LOOPS_API_KEY
- RACK_ENV=production
- RAILS_ENV=production
- RAILS_SERVE_STATIC_FILES=true
- RAILS_LOG_TO_STDOUT=true

**Worker service needs same environment variables as web service**

### Deploy Process

**Initial deploy:**
1. Push code to GitHub/GitLab
2. Connect Render to repository
3. Create services as described above
4. Render automatically builds and deploys
5. Migrations run automatically on each deploy
6. Check logs to verify success

**Subsequent deploys:**
- Push to main branch
- Render auto-deploys
- Zero-downtime deploys (Render handles this)

### Post-Deploy Checklist

- [ ] Web service is running and healthy
- [ ] Database migrations completed
- [ ] Redis connected (check Sidekiq dashboard)
- [ ] Worker service processing jobs
- [ ] Health check returns 200 OK
- [ ] Can sign up new user
- [ ] Can create advertiser
- [ ] Emails sending via Loops
- [ ] Invitations working
- [ ] SSL certificate active (Render provides free)

---

## Performance & Caching

### Database Query Optimization

**Use eager loading to avoid N+1 queries:**

```
# Bad - N+1 query
advertisers.each { |a| puts a.owner.name }

# Good - eager load
advertisers.includes(:users).each { |a| puts a.owner.name }
```

**Database indices are critical:**
- All foreign keys indexed
- Unique constraints on email, slug, etc.
- Composite indices on frequently joined columns

### Caching Strategy

**Cache user's advertiser list:**
- Key: "user:#{user.id}:advertisers"
- Invalidate when: membership created/destroyed
- TTL: 1 hour or manual invalidation

**Cache advertiser lookup by slug:**
- Key: "advertiser:slug:#{slug}"
- Invalidate when: advertiser updated
- TTL: 1 hour

**Don't cache:**
- current_user (security risk)
- Sensitive data (PII, tokens)
- Real-time data (current campaign status)

**Future caching (Phase 2+):**
- Segment contact counts
- Campaign analytics
- Dashboard metrics

### Background Job Optimization

**Sidekiq configuration:**
- Use separate queues for different priority jobs
- Critical queue (emails, notifications): 10 threads
- Default queue (data syncs): 5 threads
- Low priority (analytics): 2 threads

**Job patterns:**
- Keep jobs small and focused
- Make jobs idempotent (can run multiple times safely)
- Use perform_later for async execution
- Set timeouts to prevent hanging

---

## Testing Strategy

### Manual Testing Checklist

**Registration Flow:**
- [ ] Step 1 with invalid email → shows error
- [ ] Step 1 with weak password → shows error
- [ ] Step 1 with valid data → sends verification email
- [ ] Email verification link → unlocks Step 2
- [ ] Step 2 with missing address field → shows error
- [ ] Step 2 with invalid URL format → shows error
- [ ] Complete Step 2 → creates advertiser + owner membership
- [ ] Redirects to dashboard after completion
- [ ] User can logout and login again

**Invitation Flow - Existing User:**
- [ ] Admin sends invitation → email received
- [ ] Click invitation link while logged in → shows acceptance page
- [ ] Accept invitation → adds membership, redirects to dashboard
- [ ] Try to accept again → shows "already a member"
- [ ] Invitation expires after 7 days → shows expired message

**Invitation Flow - New User:**
- [ ] Admin sends invitation → email received
- [ ] Click link → shows welcome + password setup
- [ ] Set password → validates strength
- [ ] Continue to profile step → asks for name
- [ ] Complete profile → marks verified, logs in, redirects
- [ ] Can logout and login with new credentials

**Context Switching:**
- [ ] User with 1 advertiser → auto-selects on login
- [ ] User with 2+ advertisers → shows switcher after login
- [ ] Select advertiser from switcher → changes context, redirects
- [ ] URL shows correct slug in path
- [ ] Navbar shows current advertiser name
- [ ] Try to access different advertiser → context switches

**Role Enforcement:**
- [ ] Viewer cannot see "Invite Team Member" button
- [ ] Viewer cannot access /team/invitations/new → redirects
- [ ] Manager cannot invite users → permission denied
- [ ] Admin can invite users → succeeds
- [ ] Owner can transfer ownership → other user becomes owner
- [ ] Former owner becomes admin after transfer

**Data Isolation:**
- [ ] Create contact in Advertiser A
- [ ] Switch to Advertiser B
- [ ] Cannot see Advertiser A's contact
- [ ] Try direct URL with Advertiser A contact ID → 404 or denied
- [ ] Queries only return current advertiser's data

**Team Management:**
- [ ] Owner can change any role except their own
- [ ] Admin can change roles except owner
- [ ] Owner can remove admin → succeeds
- [ ] Admin cannot remove owner → button disabled
- [ ] Cannot remove yourself if you're only owner → error
- [ ] Remove member → they lose access immediately

**Security:**
- [ ] Login with wrong password → error message
- [ ] 5 failed logins → rate limited for 20 minutes
- [ ] Password reset email received → link works
- [ ] Reset token expires after 15 minutes → error message
- [ ] Try to access /dashboard without login → redirects to login
- [ ] Session expires after 2 weeks inactivity → must login again

### Future: Automated Tests

**Model tests:**
- User validations
- Advertiser slug generation
- AdvertiserMembership role constraints
- Only one owner per advertiser rule

**Controller tests:**
- Authentication required for protected routes
- Role permissions enforced
- Context switching works correctly
- Invitation flows complete successfully

**Integration tests:**
- Full registration flow
- Full invitation flow
- Team management workflows
- Data isolation between advertisers

**System tests (browser-based):**
- User can sign up and create advertiser
- User can accept invitation
- User can switch between advertisers
- Admin can manage team

---

## Future-Proofing

### Organization Entity (Don't Build Yet)

**Purpose:** Group multiple Advertisers under one parent entity for holding companies, resellers, multi-brand businesses.

**Prepare now:**
- Add organization_id (nullable foreign key) to advertisers table
- Add index on organization_id
- Don't use it yet, but schema is ready

**When implemented:**
```
Organization
  └── Multiple Advertisers
      └── Users with roles in each
```

**Use cases:**
- Holding company manages 10 brands, each is an Advertiser
- Reseller manages client accounts, each client is an Advertiser
- Organization-level billing and user management

### Agency Collaboration (Don't Build Yet)

**Purpose:** External agencies can be granted access to client Advertisers without being full members.

**Data model concept:**
```
Agency (similar to Advertiser)
  └── AgencyMembership (agency's internal users)
  └── AdvertiserAgencyAccess (which clients they can access)
      └── Role within each client account
```

**Use cases:**
- Marketing agency manages campaigns for multiple clients
- Agency users can switch between client accounts
- Clients can revoke agency access anytime
- Agency has limited permissions (cannot manage team, billing)

**Prepare now:**
- Keep authorization logic reusable (not hardcoded for current model)
- Consider adding agency_id to AdvertiserMembership (nullable)

### API Access (Don't Build Yet)

**Purpose:** Allow programmatic access to platform via API tokens.

**Features:**
- API tokens scoped to specific Advertiser
- Tokens have same role system (admin, manager, viewer)
- Rate limiting per token
- Token expiration and rotation

**Prepare now:**
- Keep authorization logic in service objects/methods
- Don't tightly couple to session-based auth
- Design with "actor" concept (User or API Token)

### Audit Trail (Consider Adding)

**Purpose:** Track who made what changes for compliance and debugging.

**Add to all important models:**
- created_by_id (User who created record)
- updated_by_id (User who last modified)
- Track in separate audit_logs table for full history

**Especially important for:**
- Campaign changes
- Segment modifications
- Team management actions (invite, remove, role change)
- Settings changes

**Implementation:**
- Use Current.user to auto-populate created_by/updated_by
- Use paper_trail gem for full audit history (optional)

---

## Implementation Timeline

### Week 1: Core Auth & Multitenancy

**Days 1-2: Models & Devise Setup**
- Generate Rails 8 app with PostgreSQL, Tailwind
- Add Devise gem, configure
- Create User, Advertiser, AdvertiserMembership models
- Write migrations with proper indices
- Add validations, associations, enums
- Seed database with test data

**Days 3-4: Registration & Invitation**
- Two-step registration flow (account → advertiser)
- Invitation send/accept flows
- Email verification
- Loops.so integration for emails
- Token generation/validation

**Days 5-7: Context & Scoping**
- CurrentAttributes setup (Current.user, Current.advertiser)
- ApplicationController filters (set_current_advertiser)
- AdvertiserScoped concern
- Path helper methods (current_advertiser_path)
- Advertiser switcher UI
- Role-based authorization helpers (require_role)
- Test data isolation thoroughly

### Week 2: Team Management & Polish

**Day 1: Team Management**
- Team page listing members
- Invite modal/form
- Remove member action
- Change role dropdown
- Pending invitations section
- Resend invitation feature

**Day 2: UI Polish**
- Navbar with advertiser switcher
- Breadcrumbs
- Role badges
- Empty states
- Loading states
- Error messages and flash notifications
- Responsive design (mobile-friendly)

**Day 3: Deploy to Render**
- Set up Render services (web, worker, db, redis)
- Configure environment variables
- Health check endpoint
- Deploy and test in production
- Fix any deployment issues

**Day 4: Security Hardening**
- Add rack-attack rate limiting
- Review password requirements
- Test data isolation in production
- Verify token expiration works
- Check session security

**Day 5: Documentation & Handoff**
- Write README with setup instructions
- Document environment variables needed
- Create admin guide for team management
- Test all flows one more time
- Prepare demo for stakeholders

### Week 3+: Phase 2 - Shopify Integration

**At this point, you have production-ready auth and multitenancy.**

Next phase:
- Shopify OAuth connection flow
- Background job to sync customers/orders/products
- Contact model and UI
- Simple analytics dashboard
- Then: Campaigns, Segments, Email sending

---

## Success Criteria

### Week 1 Complete When:
- [ ] User can sign up (two-step flow)
- [ ] Email verification works
- [ ] Advertiser is created with address/website
- [ ] User becomes owner of advertiser
- [ ] Owner can invite team members
- [ ] Invited users receive email via Loops
- [ ] New users complete setup (password + profile)
- [ ] Existing users can accept invitation
- [ ] Users with multiple advertisers can switch
- [ ] Data is properly isolated per advertiser
- [ ] All roles work correctly (owner/admin/manager/viewer)

### Week 2 Complete When:
- [ ] Team management page fully functional
- [ ] UI looks professional (not just default Bootstrap)
- [ ] All flows work on mobile
- [ ] Deployed to Render and publicly accessible
- [ ] Rate limiting prevents abuse
- [ ] Security basics in place
- [ ] No obvious bugs or errors
- [ ] Ready to demo to stakeholders

### Demo to Stakeholders Should Show:
1. Professional-looking signup flow
2. Email notifications working
3. Team collaboration features
4. Multi-advertiser support
5. Role-based permissions
6. Fast, responsive UI
7. "This is real, we could use this today"

**Goal:** Make the 15-person engineering team look foolish by building in 2-3 weeks what they couldn't build in 3 months with the wrong stack.

---

## Notes & Decisions

### Why Devise?
- Battle-tested, well-documented
- You already know it
- Handles 90% of auth boilerplate
- Rails 8 default auth is newer, less mature
- Don't waste time learning new auth when racing against a team

### Why Path-Based Routing?
- No DNS/subdomain configuration
- Works perfectly in all environments
- Future-proof for agencies/organizations
- Slightly longer URLs accepted trade-off

### Why Two-Step Registration?
- Better UX (smaller forms)
- Can verify email before full commitment
- Separates identity from business entity
- Room to add more onboarding steps later

### Why Loops.so?
- Purpose-built for transactional emails
- Better deliverability than DIY SMTP
- Template management in UI
- Cheaper than SendGrid for low volume
- Easy to switch later if needed

### Why This Architecture?
- Multitenancy is the foundation—get it right first
- Can't build campaigns/segments without solid tenant isolation
- Auth/permissions are hardest to retrofit
- Once this is solid, everything else is CRUD

### What Could Go Wrong?
- Underestimating UI complexity (use Tailwind UI components)
- Token/invitation edge cases (test thoroughly)
- Data isolation bugs (test with multiple advertisers)
- Performance issues (add indices, monitor queries)
- Email deliverability (monitor Loops, check spam)

### What Makes This Different From Agency Team's Approach?
- Simple, proven stack (Rails) vs complex (C# + Nuxt + GraphQL)
- Focus on shipping MVP vs building for scale
- One person owning end-to-end vs 15 people with unclear ownership
- Using AI tools effectively vs fighting the stack
- Clear requirements vs "figure it out as we go"

---

## Questions to Resolve Before Building

1. **Company name / domain?** Need to know for Loops templates, URLs in emails
2. **Loops.so account set up?** Need API key before testing emails
3. **Render account ready?** Need to deploy early and often
4. **What should dashboard show initially?** Empty state with "Connect Shopify" CTA?
5. **Should owners be able to leave if there's another admin?** Or must transfer first?
6. **Country dropdown: all countries or just US/CA?** Affects form complexity
7. **Time zone selection: during registration or in settings?** Needed for scheduling
8. **Logo/branding ready?** Even placeholder helps UI look real

---

## Conclusion

This spec gives you everything needed to build production-ready auth and multitenancy in 2-3 weeks with AI coding tools. The foundation is solid, secure, and scales to multiple advertisers per user, multiple users per advertiser, and future agency/organization features.

Once this is deployed and working, adding Shopify sync, campaigns, and segments is straightforward CRUD on top of `Current.advertiser`. You'll have a real product while the 15-person team is still debugging their GraphQL APIs.

**Start with the models and migrations. Everything else builds on that foundation.**
