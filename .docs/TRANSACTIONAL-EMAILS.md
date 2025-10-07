# Transactional Email Templates for Loops.so

## Overview
This document outlines all transactional email templates needed for the Platform Admin and Agency Partner features.

---

## Agency-Related Email Templates

### 1. Agency Client Invitation
**Template ID:** `agency_client_invitation`

**Sent when:** An advertiser invites an agency to manage their account

**Recipients:** Agency owner (and optionally admins)

**Variables:**
```javascript
{
  agency_name: "Agency Partners Inc",
  advertiser_name: "Acme Corp",
  inviter_name: "John Smith",
  inviter_email: "john@acmecorp.com",
  invitation_url: "https://nurture.com/agency_invitations/TOKEN/accept",
  expires_in_days: 7
}
```

**Subject:** `[{{advertiser_name}}] wants to work with {{agency_name}}`

**Email Body:**
```
Hi there,

{{inviter_name}} from {{advertiser_name}} has invited {{agency_name}} to help manage their direct mail campaigns on Nurture.

What this means:
• Your agency will have admin access to {{advertiser_name}}'s account
• You can assign team members to work on their campaigns
• {{advertiser_name}} can revoke access at any time

Accept this invitation to get started:
[Accept Invitation Button] → {{invitation_url}}

This invitation expires in {{expires_in_days}} days.

If you have questions, reply to {{inviter_email}} directly.

Best regards,
The Nurture Team
```

---

### 2. Agency User Client Assignment
**Template ID:** `agency_user_client_assignment`

**Sent when:** An agency owner/admin assigns a team member to a specific client

**Recipients:** The agency user being assigned

**Variables:**
```javascript
{
  user_name: "Sarah Johnson",
  client_name: "Acme Corp",
  agency_name: "Agency Partners Inc",
  role: "manager", // viewer, manager, or admin
  assigner_name: "Mike Chen",
  dashboard_url: "https://nurture.com/advertisers/acme-corp/dashboard"
}
```

**Subject:** `You've been assigned to {{client_name}}`

**Email Body:**
```
Hi {{user_name}},

{{assigner_name}} has assigned you to work with {{client_name}} as part of {{agency_name}}'s team.

Your Access Level: {{role}}

What you can do:
{{#if role == 'admin'}}
• Full admin access to manage campaigns
• View all analytics and reports
• Manage campaign settings
{{/if}}
{{#if role == 'manager'}}
• Create and edit campaigns
• View analytics and reports
• Cannot modify account settings
{{/if}}
{{#if role == 'viewer'}}
• View campaigns and analytics
• Cannot create or edit campaigns
{{/if}}

Access the client dashboard:
[Go to {{client_name}}] → {{dashboard_url}}

If you have questions about your role, contact {{assigner_name}}.

Best regards,
The Nurture Team
```

---

### 3. Agency Access Revoked
**Template ID:** `agency_access_revoked`

**Sent when:** An advertiser revokes an agency's access

**Recipients:** Agency owner and assigned team members

**Variables:**
```javascript
{
  agency_name: "Agency Partners Inc",
  client_name: "Acme Corp",
  revoker_name: "John Smith",
  revoked_at: "2025-10-07T10:30:00Z"
}
```

**Subject:** `Access to {{client_name}} has been revoked`

**Email Body:**
```
Hi there,

{{revoker_name}} from {{client_name}} has revoked {{agency_name}}'s access to their account.

What this means:
• You can no longer access {{client_name}}'s campaigns
• All assigned team members have lost access
• Any pending work should be completed outside the platform

If you believe this was done in error, please contact {{client_name}} directly.

Best regards,
The Nurture Team
```

---

### 4. Agency Client Assignment Removed
**Template ID:** `agency_client_assignment_removed`

**Sent when:** An agency owner/admin removes a team member's access to a client

**Recipients:** The agency user being removed

**Variables:**
```javascript
{
  user_name: "Sarah Johnson",
  client_name: "Acme Corp",
  agency_name: "Agency Partners Inc",
  remover_name: "Mike Chen"
}
```

**Subject:** `Your access to {{client_name}} has been removed`

**Email Body:**
```
Hi {{user_name}},

{{remover_name}} has removed your access to {{client_name}} as part of {{agency_name}}'s team.

You will no longer be able to:
• Access {{client_name}}'s dashboard
• View or edit their campaigns
• See their analytics

If you have questions about this change, contact {{remover_name}}.

Best regards,
The Nurture Team
```

---

## Existing Email Templates (Updated for Context)

### Email Verification
*No changes needed - already implemented*

### Team Invitation
*No changes needed - already implemented*

### Password Reset
*No changes needed - already implemented*

---

## Email Template Configuration in Loops.so

### Setup Steps

1. **Create Templates**
   - Log into Loops.so
   - Navigate to Templates
   - Create each template with the IDs above
   - Use the email body structures provided

2. **Add Variables**
   - Define all variables in each template
   - Set appropriate defaults where applicable
   - Test variable rendering

3. **Design Emails**
   - Use Loops visual editor for styling
   - Match Nurture's brand colors
   - Ensure mobile responsiveness
   - Add unsubscribe footer (for non-critical emails)

4. **Test Emails**
   - Send test emails with sample data
   - Verify all variables render correctly
   - Check links work properly
   - Test on multiple email clients

---

## Mailer Implementation

### Create Agency Mailer

```ruby
# app/mailers/agency_mailer.rb
class AgencyMailer < ApplicationMailer
  def client_invitation(access)
    @access = access
    @agency = access.agency
    @advertiser = access.advertiser
    @inviter = Current.user
    
    agency_owner = @agency.owner
    
    mail(
      to: agency_owner.email,
      subject: "#{@advertiser.name} wants to work with #{@agency.name}",
      template_id: 'agency_client_invitation',
      template_variables: {
        agency_name: @agency.name,
        advertiser_name: @advertiser.name,
        inviter_name: @inviter.display_name,
        inviter_email: @inviter.email,
        invitation_url: accept_agency_invitation_url(access.generate_token_for(:invitation)),
        expires_in_days: 7
      }
    )
  end
  
  def user_client_assignment(assignment)
    @assignment = assignment
    @user = assignment.user
    @client = assignment.advertiser
    @agency = assignment.agency
    @assigner = Current.user
    
    mail(
      to: @user.email,
      subject: "You've been assigned to #{@client.name}",
      template_id: 'agency_user_client_assignment',
      template_variables: {
        user_name: @user.display_name,
        client_name: @client.name,
        agency_name: @agency.name,
        role: @assignment.role,
        assigner_name: @assigner.display_name,
        dashboard_url: advertiser_dashboard_url(@client.slug)
      }
    )
  end
  
  def access_revoked(access)
    @access = access
    @agency = access.agency
    @client = access.advertiser
    @revoker = Current.user
    
    # Send to agency owner
    agency_owner = @agency.owner
    
    mail(
      to: agency_owner.email,
      subject: "Access to #{@client.name} has been revoked",
      template_id: 'agency_access_revoked',
      template_variables: {
        agency_name: @agency.name,
        client_name: @client.name,
        revoker_name: @revoker.display_name,
        revoked_at: @access.revoked_at.iso8601
      }
    )
  end
  
  def assignment_removed(assignment)
    @assignment = assignment
    @user = assignment.user
    @client = assignment.advertiser
    @agency = assignment.agency
    @remover = Current.user
    
    mail(
      to: @user.email,
      subject: "Your access to #{@client.name} has been removed",
      template_id: 'agency_client_assignment_removed',
      template_variables: {
        user_name: @user.display_name,
        client_name: @client.name,
        agency_name: @agency.name,
        remover_name: @remover.display_name
      }
    )
  end
end
```

---

## Integration Points

### Where to Trigger Emails

1. **Client Invitation**
   - File: `app/controllers/settings/agencies_controller.rb`
   - Method: `create`
   - After: `AdvertiserAgencyAccess.create!`

2. **User Assignment**
   - File: `app/controllers/agencies/client_assignments_controller.rb`
   - Method: `create`
   - After: `AgencyClientAssignment.create!`

3. **Access Revoked**
   - File: `app/controllers/settings/agencies_controller.rb`
   - Method: `destroy`
   - After: `access.revoke!`

4. **Assignment Removed**
   - File: `app/controllers/agencies/client_assignments_controller.rb`
   - Method: `destroy`
   - After: `assignment.destroy!`

---

## Testing Checklist

- [ ] All template IDs match in Loops.so and code
- [ ] All variables are defined in templates
- [ ] Test emails sent successfully
- [ ] Links in emails work correctly
- [ ] Emails render properly on mobile
- [ ] Unsubscribe links work (where applicable)
- [ ] Email delivery tracked in Loops dashboard
- [ ] Bounce handling configured
- [ ] Rate limiting configured if needed

---

## Notes

### Email Priorities
- **Critical:** Client invitation (needed for core workflow)
- **High:** User assignment (improves UX)
- **Medium:** Access revoked (informational)
- **Low:** Assignment removed (nice to have)

### Implementation Strategy
1. Start with placeholder emails (just subject + plain text)
2. Implement mailer methods
3. Test delivery with real addresses
4. Design proper HTML templates in Loops
5. Gradually enhance with better copy and design

### Alternative: Skip Emails Initially
For MVP, you could:
- Show in-app notifications instead
- Use basic ActionMailer without Loops
- Add Loops integration in Phase 3

