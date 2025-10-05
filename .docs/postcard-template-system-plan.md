# Postcard Template System - Implementation Plan

## Overview
Build a template customization system with 3-5 pre-designed HTML/CSS postcard templates. Users select a template via thumbnail radio buttons and fill in standardized fields (no canvas editing).

## 🎯 Goals
- **User-friendly**: Simple form inputs, no design skills needed
- **Professional**: Beautiful, conversion-optimized templates
- **Flexible**: Support common postcard use cases
- **Fast**: Quick to customize and preview
- **Lob-compatible**: Renders properly via Lob's HTML API

---

## 📐 Template Design Specifications

### Postcard Size
- **6x9 inches** (current default)
- 1800x1350 pixels @ 300 DPI
- Front: Full bleed creative
- Back: Address area + message area

### Template Categories (5 Templates)

#### 1. **"Bold Offer"** - Discount/Promotion Template
**Best for**: Sales, discounts, special offers
**Front fields**:
- Headline (e.g., "50% OFF")
- Subheadline (e.g., "Summer Sale")
- Body text (e.g., "Save on all items")
- Call-to-action (e.g., "Shop Now")
- Background color/image
- Logo

**Back fields**:
- Offer details
- Expiration date
- Website/phone
- Terms (small print)

#### 2. **"Product Showcase"** - Single Product Focus
**Best for**: Product launches, featured items
**Front fields**:
- Product image URL
- Headline (product name)
- Tagline
- Price/offer
- Logo

**Back fields**:
- Product description (2-3 lines)
- Benefits (bulleted)
- CTA
- Website/QR code

#### 3. **"Event Invitation"** - Event/Webinar
**Best for**: Events, workshops, grand openings
**Front fields**:
- Event name
- Date & time
- Location (or "Virtual")
- Eye-catching image
- "You're Invited" text

**Back fields**:
- Event details
- RSVP instructions
- What to expect
- Contact info

#### 4. **"Welcome/Thank You"** - Relationship Building
**Best for**: New customers, thank you notes
**Front fields**:
- Greeting (Hi {{first_name}}!)
- Main message
- Personal signature
- Brand colors
- Logo

**Back fields**:
- Secondary message
- Next steps
- Contact information
- Social media

#### 5. **"Seasonal/Holiday"** - Holiday Promotions
**Best for**: Holiday sales, seasonal campaigns
**Front fields**:
- Holiday theme (Christmas, Black Friday, etc.)
- Headline
- Offer/message
- Festive imagery
- Logo

**Back fields**:
- Offer details
- Dates
- CTA
- Terms

---

## 🗄️ Database Schema

### New Table: `postcard_templates`
```ruby
create_table :postcard_templates do |t|
  t.string :name, null: false              # "Bold Offer"
  t.string :slug, null: false              # "bold-offer"
  t.text :description                      # "Perfect for promotions..."
  t.string :category                       # "offer", "product", "event", "welcome", "seasonal"
  t.string :thumbnail_url                  # "/images/templates/bold-offer-thumb.png"
  t.string :preview_url                    # "/images/templates/bold-offer-preview.png"
  
  # HTML templates with merge variables
  t.text :front_html, null: false
  t.text :back_html, null: false
  
  # CSS (inline or separate)
  t.text :front_css
  t.text :back_css
  
  # Field configuration (JSON)
  t.text :front_fields                     # JSON: [{name: "headline", type: "text", label: "Headline", ...}]
  t.text :back_fields                      # JSON: same structure
  
  # Default values for preview
  t.text :default_values                   # JSON: {headline: "50% OFF", ...}
  
  t.boolean :active, default: true
  t.integer :sort_order, default: 0
  
  t.timestamps
end

add_index :postcard_templates, :slug, unique: true
add_index :postcard_templates, :sort_order
```

### Update Table: `campaigns`
```ruby
# Add columns to campaigns table
add_column :campaigns, :postcard_template_id, :integer
add_column :campaigns, :template_data, :text  # JSON: store customized field values

add_foreign_key :campaigns, :postcard_templates
add_index :campaigns, :postcard_template_id
```

---

## 🎨 Template HTML Structure

### Example: Bold Offer Template

#### Front HTML
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      width: 1800px;
      height: 1350px;
      font-family: 'Helvetica Neue', Arial, sans-serif;
      background: {{background_color}};
      background-image: url('{{background_image}}');
      background-size: cover;
      display: flex;
      align-items: center;
      justify-content: center;
      text-align: center;
      padding: 100px;
    }
    .logo {
      position: absolute;
      top: 60px;
      left: 60px;
      max-width: 300px;
      max-height: 150px;
    }
    .content {
      z-index: 10;
    }
    .headline {
      font-size: 180px;
      font-weight: 900;
      color: {{headline_color}};
      text-shadow: 2px 2px 8px rgba(0,0,0,0.2);
      line-height: 1;
      margin-bottom: 30px;
    }
    .subheadline {
      font-size: 80px;
      font-weight: 700;
      color: {{subheadline_color}};
      margin-bottom: 40px;
    }
    .body-text {
      font-size: 50px;
      color: {{body_color}};
      margin-bottom: 60px;
    }
    .cta {
      font-size: 60px;
      font-weight: 700;
      background: {{cta_bg_color}};
      color: {{cta_text_color}};
      padding: 30px 80px;
      border-radius: 15px;
      display: inline-block;
    }
  </style>
</head>
<body>
  <img src="{{logo_url}}" class="logo" alt="Logo" />
  <div class="content">
    <div class="headline">{{headline}}</div>
    <div class="subheadline">{{subheadline}}</div>
    <div class="body-text">{{body_text}}</div>
    <div class="cta">{{cta_text}}</div>
  </div>
</body>
</html>
```

#### Back HTML (simpler - leave room for address)
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      width: 1800px;
      height: 1350px;
      font-family: 'Helvetica Neue', Arial, sans-serif;
      background: #fff;
      padding: 80px;
      /* Right side reserved for address */
    }
    .message-area {
      width: 900px; /* Left half */
      float: left;
    }
    .offer-details {
      font-size: 38px;
      color: #333;
      line-height: 1.6;
      margin-bottom: 40px;
    }
    .expiration {
      font-size: 32px;
      color: #e53e3e;
      font-weight: 700;
      margin-bottom: 40px;
    }
    .contact {
      font-size: 36px;
      color: #2d3748;
      font-weight: 600;
      margin-bottom: 20px;
    }
    .terms {
      font-size: 20px;
      color: #718096;
      margin-top: 40px;
      line-height: 1.4;
    }
  </style>
</head>
<body>
  <div class="message-area">
    <div class="offer-details">{{offer_details}}</div>
    <div class="expiration">Expires: {{expiration_date}}</div>
    <div class="contact">{{website}}</div>
    <div class="contact">{{phone}}</div>
    <div class="terms">{{terms}}</div>
  </div>
  <!-- Right side left blank for Lob's address placement -->
</body>
</html>
```

---

## 💻 Implementation Steps

### Phase 1: Database & Models (30 min)
1. Create migration for `postcard_templates` table
2. Create `PostcardTemplate` model with validations
3. Update `Campaign` model with template association
4. Serialize `template_data` JSON field

### Phase 2: Seed Templates (45 min)
1. Create 5 HTML/CSS templates (one per category)
2. Define field configurations for each
3. Seed database with template records
4. Generate thumbnail images (can be screenshots initially)

### Phase 3: Template Selection UI (1 hour)
1. Update `campaigns/edit` Design tab
2. Show template thumbnails in grid
3. Radio button selection
4. Display selected template name/description
5. Live preview of selected template (optional for MVP)

### Phase 4: Field Customization UI (1 hour)
1. Dynamic form fields based on selected template
2. Text inputs, textareas, color pickers
3. Store values in `campaign.template_data` JSON
4. Real-time character counting for fields
5. Field validation (max lengths, required fields)

### Phase 5: Template Rendering (45 min)
1. Update `LobClient` to use template HTML
2. Replace merge variables with actual values
3. Combine `template_data` with `merge_variables`
4. Handle missing/default values gracefully

### Phase 6: Preview & Polish (30 min)
1. Template preview modal (optional)
2. Error handling for malformed templates
3. Testing with Lob test API
4. UI polish and responsive design

---

## 📝 Field Configuration Structure

### JSON Format for `front_fields`
```json
[
  {
    "name": "headline",
    "type": "text",
    "label": "Headline",
    "placeholder": "50% OFF",
    "required": true,
    "max_length": 20,
    "help_text": "Short, attention-grabbing text"
  },
  {
    "name": "subheadline",
    "type": "text",
    "label": "Subheadline",
    "placeholder": "Summer Sale",
    "required": false,
    "max_length": 40
  },
  {
    "name": "body_text",
    "type": "textarea",
    "label": "Body Text",
    "placeholder": "Save on all summer items",
    "required": false,
    "max_length": 100,
    "rows": 3
  },
  {
    "name": "cta_text",
    "type": "text",
    "label": "Call to Action",
    "placeholder": "Shop Now",
    "required": true,
    "max_length": 15
  },
  {
    "name": "background_color",
    "type": "color",
    "label": "Background Color",
    "default": "#FF6B6B"
  },
  {
    "name": "logo_url",
    "type": "url",
    "label": "Logo URL",
    "placeholder": "https://...",
    "help_text": "Leave blank to use advertiser logo"
  }
]
```

---

## 🎯 User Flow

### Campaign Creation Flow (Updated)
1. **Create Campaign** → Enter name/description
2. **Add Recipients** → Upload CSV or manual entry
3. **Design** (New Experience):
   ```
   ┌─────────────────────────────────────┐
   │ Choose Template                     │
   ├─────────────────────────────────────┤
   │ [📋 Bold Offer]  [📦 Product]      │
   │ [🎉 Event]       [💌 Welcome]      │
   │ [🎄 Seasonal]                       │
   └─────────────────────────────────────┘
   
   ┌─────────────────────────────────────┐
   │ Customize: Bold Offer Template      │
   ├─────────────────────────────────────┤
   │ Front Side:                         │
   │ Headline: [50% OFF____________] 20  │
   │ Subheadline: [Summer Sale_____] 40  │
   │ Body: [Save on all items______] 100 │
   │ CTA: [Shop Now_______________] 15   │
   │ Background: [#FF6B6B] 🎨           │
   │                                     │
   │ Back Side:                          │
   │ Offer: [All summer clothing...] 200 │
   │ Expires: [12/31/2024_________]     │
   │ Website: [www.store.com______]     │
   │ Phone: [(555) 123-4567______]      │
   │                                     │
   │ [Preview] [Save Template]           │
   └─────────────────────────────────────┘
   ```
4. **Review & Send** → Calculate cost, send campaign

---

## 🔧 Technical Considerations

### Merge Variables
```ruby
# Available variables (auto-populated):
{
  first_name: "John",
  last_name: "Doe",
  full_name: "John Doe",
  company: "Acme Corp",
  # Plus any custom template_data fields
  headline: "50% OFF",
  subheadline: "Summer Sale",
  # ...
}
```

### HTML Rendering
```ruby
# In LobClient
def render_template(template, data)
  html = template.front_html.dup
  
  # Replace all {{variable}} with actual values
  data.each do |key, value|
    html.gsub!("{{#{key}}}", value.to_s)
  end
  
  # Handle missing variables (use defaults or empty)
  html.gsub!(/\{\{(\w+)\}\}/, '')
  
  html
end
```

### Performance
- Cache rendered HTML for repeated sends
- Validate HTML structure on template save
- Limit template file sizes (< 100KB per side)

### Security
- Sanitize user input before rendering
- No JavaScript execution in templates
- Validate URLs for logos/images
- Escape HTML special characters in text fields

---

## 📊 Success Metrics

- Template selection rate (which templates are popular?)
- Time to create campaign (should decrease)
- Campaign send success rate (proper HTML rendering)
- User satisfaction (fewer support requests?)

---

## 🚀 Future Enhancements (Post-MVP)

- [ ] Custom template creation (admin only)
- [ ] Template marketplace/library
- [ ] A/B testing different templates
- [ ] Image upload and hosting
- [ ] QR code generation
- [ ] Variable fonts and advanced styling
- [ ] Template preview with actual recipient data
- [ ] Duplicate/clone existing templates
- [ ] Template analytics (conversion tracking)

---

## 📋 Questions for Review

1. **Template Count**: Start with 3 or all 5 templates?
2. **Field Types**: Need image upload or just URL input?
3. **Color Picker**: Full color picker or predefined palette?
4. **Preview**: Show live preview or just thumbnail selection?
5. **Advertiser Logo**: Auto-include advertiser logo in templates?
6. **Default Values**: Pre-fill with advertiser info (name, website, etc.)?

---

## 🎨 Example Templates Priority

**MVP (Start with 3)**:
1. Bold Offer (most versatile)
2. Welcome/Thank You (relationship building)
3. Event Invitation (time-sensitive)

**Phase 2 (Add later)**:
4. Product Showcase
5. Seasonal/Holiday

---

## ⏱️ Time Estimate

- **Phase 1** (DB/Models): 30 min
- **Phase 2** (Template Creation): 45 min
- **Phase 3** (Selection UI): 1 hour
- **Phase 4** (Field UI): 1 hour
- **Phase 5** (Rendering): 45 min
- **Phase 6** (Polish): 30 min

**Total: ~4.5 hours**

---

## 🤔 Your Feedback Needed

Please review and let me know:
- ✅ Approve this plan as-is
- 🔧 Modifications needed
- 💭 Additional considerations
- 🚦 Ready to start implementing?

I'm ready to build this once you give the green light! 🚀

