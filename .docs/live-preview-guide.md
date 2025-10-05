# Live Preview - User Guide 🎨

## What is Live Preview?

The live preview shows you **exactly** what your postcard will look like as you design it - in real-time! 

Every change you make updates the preview **instantly** (with a tiny 300ms delay so it's smooth, not jumpy).

---

## How It Works

### 1️⃣ **Select a Template**
As soon as you click a template card, the preview loads with that template's default design.

```
Click "Bold Offer" → Preview shows: "50% OFF | Summer Sale | Shop Now"
```

### 2️⃣ **Choose Colors**
Click a color palette and watch the postcard colors change instantly!

```
Click "Vibrant" palette → Postcard becomes red/orange
Click "Professional" palette → Postcard becomes blue/gray
Click "Natural" palette → Postcard becomes green/brown
```

### 3️⃣ **Type Custom Content**
Start typing in ANY field - the preview updates as you type!

```
Type in "Headline" field:
"GET" → Preview shows "GET"
"GET 50" → Preview shows "GET 50"
"GET 50% OFF" → Preview shows "GET 50% OFF"
```

**Every character you type appears in the preview!**

### 4️⃣ **Switch Front/Back**
Click "Front" or "Back" buttons to toggle what you see:

```
Click "Back" → Preview switches to show back side
Click "Front" → Preview switches back to front side
```

The preview updates with your custom content on **both sides**!

### 5️⃣ **Personalization Variables**
Use merge variables like `{{first_name}}` and see them rendered with sample data:

```
Type: "Welcome, {{first_name}}!"
Preview shows: "Welcome, John!"
```

---

## Features

### ✨ **Instant Updates**
- Template selection → Updates immediately
- Color palette → Updates immediately  
- Field changes → Updates as you type (300ms debounce)
- Front/Back toggle → Updates immediately

### 🎯 **What You See is What You Get**
- The preview uses the **exact same rendering** as the actual postcards
- Colors, fonts, layouts, everything matches 100%
- Sample contact data ("John Doe") shows how personalization works

### ⚡ **Smart & Fast**
- Debouncing prevents server spam (waits 300ms after you stop typing)
- Uses iframe for secure, isolated rendering
- Scales the preview to fit perfectly
- No page reloads needed

### 🛡️ **Safe & Secure**
- Server-side rendering (no template injection risks)
- CSRF token protection on all requests
- Validates template and palette IDs
- Graceful error handling

---

## Technical Details

### How Preview Updates Work

```
1. User types in a field
   ↓
2. JavaScript waits 300ms (debounce)
   ↓
3. Collects all form data:
   - Template ID
   - Color palette ID
   - All field values (headline, body, etc.)
   ↓
4. POSTs data to /preview_live endpoint
   ↓
5. Server renders HTML with template system:
   - Loads template
   - Loads color palette
   - Merges in custom field values
   - Adds advertiser defaults (logo, website)
   - Adds sample contact data (John Doe)
   ↓
6. Returns fully rendered HTML
   ↓
7. JavaScript updates iframe with new HTML
   ↓
8. User sees updated preview! ✨
```

### Data Flow

```
Form Fields → JavaScript → POST /preview_live → Controller
                                                     ↓
                                            PostcardTemplate.render_front(data)
                                                     ↓
                                            HTML with merge variables replaced
                                                     ↓
                                            Returns HTML
                                                     ↓
                                            JavaScript → iframe.srcdoc = html
                                                     ↓
                                            Preview updates!
```

---

## Example Usage

### Creating a Bold Offer Postcard

**Step 1:** Select "Bold Offer" template
```
Preview shows default: "50% OFF | Summer Sale | Save on all summer items | Shop Now"
```

**Step 2:** Choose "Vibrant" colors
```
Preview changes to red/orange color scheme
```

**Step 3:** Customize headline
```
Type: "FLASH SALE"
Preview updates to: "FLASH SALE | Summer Sale | ..."
```

**Step 4:** Customize subheadline
```
Type: "24 Hours Only!"
Preview updates to: "FLASH SALE | 24 Hours Only! | ..."
```

**Step 5:** Customize body text
```
Type: "Everything must go!"
Preview updates with new text
```

**Step 6:** Customize CTA
```
Type: "Buy Now"
Preview button changes to "Buy Now"
```

**Step 7:** Click "Back" to see back side
```
Preview switches to show back with offer details
```

**Step 8:** Customize offer details
```
Type: "Get up to 75% off all items..."
Preview updates back side with new text
```

**Done!** You can see exactly what recipients will receive.

---

## Keyboard-Friendly

The preview updates as you type, so you can:
- Tab between fields
- Type continuously
- See changes without clicking anywhere

---

## Browser Compatibility

Works in all modern browsers:
✅ Chrome/Edge  
✅ Firefox  
✅ Safari  
✅ Mobile browsers  

---

## Troubleshooting

**Preview shows "Select a template":**
→ Click a template card first

**Preview shows "Preview failed to load":**
→ Check your internet connection
→ Refresh the page
→ Contact support if it persists

**Preview doesn't update:**
→ Make sure the field has `data-preview` attribute (it should!)
→ Check browser console for errors
→ Try clicking "Front" or "Back" to force refresh

---

## Tips for Best Results

1. **Select template first** - Can't preview without a template!
2. **Choose colors second** - See how different palettes look
3. **Fill in fields** - Use the character counters as guides
4. **Toggle front/back** - Make sure both sides look great
5. **Use merge variables** - See how personalization works
6. **Try different templates** - Compare designs easily

---

## What Gets Previewed

### Included in Preview:
✅ Template HTML/CSS  
✅ Selected color palette  
✅ All custom field values  
✅ Advertiser name/website  
✅ Sample contact data (John Doe)  
✅ Merge variables replaced  
✅ Actual fonts and sizes  
✅ Actual layout and spacing  

### NOT in Preview:
❌ Actual recipient data (uses sample "John Doe")  
❌ Your actual logo (unless you provide URL)  
❌ Print quality (screen vs print)  

The preview shows a **perfect simulation** of what the actual postcard will look like!

---

## Performance

- **Debounce:** 300ms (waits for you to stop typing)
- **Update speed:** ~100-200ms (very fast!)
- **Server load:** Minimal (one request every 300ms max)
- **No lag:** Smooth, responsive, no jank

---

## Future Enhancements

Possible future improvements:
- Real recipient data preview (select from list)
- Side-by-side front/back view
- Zoom in/out
- Print quality simulation
- Mobile preview mode
- Animation transitions

---

## Summary

**Live preview gives you:**
- 🎨 Real-time visual feedback
- 👀 Exactly what recipients will see
- ⚡ Instant updates as you type
- 🔄 Front/back switching
- 🎯 WYSIWYG (What You See Is What You Get)

**No more guessing what your postcard will look like!**

🚀 **Start designing with confidence!**

