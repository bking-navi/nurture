# Deployment Checklist for Render

## Environment Variables to Set in Render

Add these in your Render dashboard under "Environment":

1. **LOOPS_API_KEY** - Your Loops.so API key
2. **APP_HOST** - Your Render domain (e.g., `nurture.onrender.com`)
3. **RAILS_MASTER_KEY** - Copy from `config/master.key` (for encrypted credentials)
4. **SECRET_KEY_BASE** - Rails will generate this automatically, or run `rails secret`

## Loops.so Template Configuration

Make sure you've created these transactional email templates in Loops:

### Template 1: Email Verification
- **Transactional ID**: Copy from your Loops dashboard
- **Required Variables**: 
  - `first_name` - User's first name
  - `verification_url` - Full URL with confirmation token
- **Add the Template ID to Rails Credentials**:
  ```bash
  rails credentials:edit
  ```
  Add:
  ```yaml
  loops:
    templates:
      email_verification: YOUR_TEMPLATE_ID_HERE
  ```

### Template 2: Password Reset (for future use)
- **Transactional ID**: Copy from your Loops dashboard
- **Required Variables**:
  - `first_name` - User's first name
  - `reset_url` - Full URL with reset token
- **Add to credentials**:
  ```yaml
  loops:
    templates:
      password_reset: YOUR_TEMPLATE_ID_HERE
  ```

## Database Configuration

Rails 8 uses SQLite by default for all environments. For production on Render:

### Option 1: Use PostgreSQL (Recommended)
1. Add PostgreSQL database in Render
2. Update `config/database.yml` production section to use PostgreSQL
3. Add `pg` gem to Gemfile

### Option 2: Keep SQLite (Simpler, but data is ephemeral)
- Current setup - works out of the box
- **Note**: Data will be lost on redeploys with free tier

## Pre-Deployment Steps

- [ ] Commit all changes
- [ ] Push to GitHub/GitLab
- [ ] Verify `.env` is in `.gitignore` (it should be)
- [ ] Make sure `config/master.key` is NOT committed (add to `.gitignore`)

## Post-Deployment Steps

- [ ] Run migrations: `rails db:migrate` (Render does this automatically)
- [ ] Test signup flow
- [ ] Test email verification
- [ ] Check logs for any errors

## Testing in Production

1. Sign up with a real email address
2. Check that you receive the verification email from Loops
3. Click the verification link
4. Verify you can sign in
5. Check Render logs for any errors

## Troubleshooting

### Email not sending
- Check `LOOPS_API_KEY` is set correctly in Render
- Check Loops dashboard for API errors
- Check Render logs for error messages

### Verification links not working
- Check `APP_HOST` environment variable
- Make sure it's set to your actual Render domain (without `https://`)

### Database errors
- Make sure migrations ran successfully
- Check Render deployment logs

