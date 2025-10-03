# Quick Render Deployment Guide

## Step 1: Environment Variables in Render

Add these to your Render service (Environment tab):

```
LOOPS_API_KEY=e5bb4bdc0eff55fc9e33ec4a82634ebe
RAILS_MASTER_KEY=900d0bab6197e1bdbde210da214702c3
APP_HOST=your-app-name.onrender.com
SECRET_KEY_BASE=(Render generates this automatically, or run: rails secret)
```

**IMPORTANT**: Update `APP_HOST` with your actual Render domain!

## Step 2: Loops Template IDs

You need to add the Loops template IDs to your Rails credentials:

1. Run: `rails credentials:edit`
2. Add:
```yaml
loops:
  api_key: <%= ENV['LOOPS_API_KEY'] %>
  templates:
    email_verification: cmgbadhp01am32t0igojlslh3
    password_reset: YOUR_PASSWORD_RESET_TEMPLATE_ID
```

## Step 3: Database

Current setup uses SQLite. For production, you may want PostgreSQL:

1. Add PostgreSQL database in Render
2. Render will set `DATABASE_URL` automatically
3. Update `Gemfile` to include `pg` gem in production

## Step 4: Deploy

1. Commit and push to GitHub
2. Connect Render to your GitHub repo
3. Render will automatically:
   - Install dependencies
   - Run migrations
   - Start your app

## Step 5: Test

1. Visit your Render URL
2. Sign up with a real email
3. Check that verification email arrives
4. Click the link and verify it works

## Current Status

✅ Slice 1 Complete: User signup with email verification
✅ Development tested and working
✅ Loops integration configured
✅ Ready for production deployment

## What's Not Implemented Yet

- Advertiser creation (Slice 2)
- Team management
- Path-based routing

These will be added in future slices after Slice 1 is tested in production.

