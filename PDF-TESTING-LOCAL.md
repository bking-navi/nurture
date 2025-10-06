# Testing PDF Uploads Locally

## The Problem
Lob's API needs to download PDF files from a publicly accessible URL. In local development, `http://localhost:3000` is not accessible from the internet, so Lob can't download your PDFs.

## Solution: Use ngrok

### 1. Install ngrok
```bash
# macOS
brew install ngrok

# Or download from https://ngrok.com/download
```

### 2. Create a free ngrok account
- Go to https://dashboard.ngrok.com/signup
- Sign up for a free account
- Copy your authtoken from https://dashboard.ngrok.com/get-started/your-authtoken

### 3. Configure ngrok
```bash
ngrok config add-authtoken YOUR_AUTH_TOKEN
```

### 4. Start your Rails server
```bash
bin/dev
```

### 5. In a NEW terminal window, start ngrok
```bash
ngrok http 3000
```

You'll see output like:
```
Forwarding  https://abc123.ngrok-free.app -> http://localhost:3000
```

### 6. Set the NGROK_URL environment variable
Copy the `https://` URL from ngrok and add it to your `.env.development.local` file:

```bash
# .env.development.local (create this file if it doesn't exist)
NGROK_URL=https://abc123.ngrok-free.app
```

### 7. Restart your Rails server
Stop `bin/dev` (Ctrl+C) and start it again:
```bash
bin/dev
```

### 8. Access your app via the ngrok URL
Instead of `http://localhost:3000`, use the ngrok URL in your browser:
```
https://abc123.ngrok-free.app
```

Now when you send a campaign with PDFs, Lob will be able to download them!

---

## Alternative: Skip PDF Testing Locally

If you don't want to set up ngrok, you can:

1. **Use HTML templates for local testing** (no ngrok needed)
2. **Deploy to production and test PDFs there** (production already has a public URL)

In production on Render, make sure you set:
```bash
APP_URL=https://navistone.dev
```

This will automatically work without ngrok.

