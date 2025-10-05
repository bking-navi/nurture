# Postcard Templates Seed Data
# Creates 5 professional postcard templates

puts "🎨 Seeding Postcard Templates..."

# Clear existing templates (only in development)
if Rails.env.development?
  PostcardTemplate.destroy_all
  puts "  ✓ Cleared existing templates"
end

# Template 1: Bold Offer
PostcardTemplate.create!(
  name: "Bold Offer",
  slug: "bold-offer",
  category: "offer",
  description: "Perfect for promotions, discounts, and special offers. Eye-catching design that converts.",
  sort_order: 1,
  front_html: <<~HTML,
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
          background: {{color_primary}};
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          padding: 100px;
          position: relative;
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
          font-size: 200px;
          font-weight: 900;
          color: #FFFFFF;
          text-shadow: 4px 4px 12px rgba(0,0,0,0.3);
          line-height: 0.9;
          margin-bottom: 40px;
          letter-spacing: -2px;
        }
        .subheadline {
          font-size: 90px;
          font-weight: 700;
          color: #FFFFFF;
          margin-bottom: 50px;
          text-shadow: 2px 2px 8px rgba(0,0,0,0.2);
        }
        .body-text {
          font-size: 56px;
          color: #FFFFFF;
          margin-bottom: 70px;
          line-height: 1.4;
        }
        .cta {
          font-size: 68px;
          font-weight: 800;
          background: {{color_cta_bg}};
          color: {{color_cta_text}};
          padding: 35px 90px;
          border-radius: 20px;
          display: inline-block;
          text-transform: uppercase;
          letter-spacing: 2px;
          box-shadow: 0 8px 20px rgba(0,0,0,0.3);
        }
      </style>
    </head>
    <body>
      <img src="{{logo_url}}" class="logo" alt="Logo" onerror="this.style.display='none'" />
      <div class="content">
        <div class="headline">{{headline}}</div>
        <div class="subheadline">{{subheadline}}</div>
        <div class="body-text">{{body_text}}</div>
        <div class="cta">{{cta_text}}</div>
      </div>
    </body>
    </html>
  HTML
  back_html: <<~HTML,
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
          background: #FFFFFF;
          padding: 80px;
        }
        .message-area {
          width: 850px;
          float: left;
        }
        .offer-details {
          font-size: 42px;
          color: #2D3748;
          line-height: 1.6;
          margin-bottom: 50px;
        }
        .expiration {
          font-size: 38px;
          color: #E53E3E;
          font-weight: 700;
          margin-bottom: 50px;
          padding: 20px;
          background: #FFF5F5;
          border-left: 6px solid #E53E3E;
        }
        .contact {
          font-size: 40px;
          color: {{color_primary}};
          font-weight: 600;
          margin-bottom: 25px;
        }
        .terms {
          font-size: 24px;
          color: #718096;
          margin-top: 50px;
          line-height: 1.5;
        }
      </style>
    </head>
    <body>
      <div class="message-area">
        <div class="offer-details">{{offer_details}}</div>
        <div class="expiration">⏰ Expires: {{expiration_date}}</div>
        <div class="contact">🌐 {{website}}</div>
        <div class="contact">📞 {{phone}}</div>
        <div class="terms">{{terms}}</div>
      </div>
    </body>
    </html>
  HTML
  front_fields: [
    { name: "headline", type: "text", label: "Headline", placeholder: "50% OFF", required: true, max_length: 20 },
    { name: "subheadline", type: "text", label: "Subheadline", placeholder: "Summer Sale", required: false, max_length: 30 },
    { name: "body_text", type: "textarea", label: "Body Text", placeholder: "Save on all items", required: false, max_length: 80, rows: 2 },
    { name: "cta_text", type: "text", label: "Call to Action", placeholder: "Shop Now", required: true, max_length: 15 },
    { name: "logo_url", type: "url", label: "Logo URL", placeholder: "https://...", required: false }
  ],
  back_fields: [
    { name: "offer_details", type: "textarea", label: "Offer Details", placeholder: "Get 50% off all summer clothing...", required: true, max_length: 200, rows: 3 },
    { name: "expiration_date", type: "text", label: "Expiration Date", placeholder: "12/31/2024", required: true, max_length: 20 },
    { name: "website", type: "text", label: "Website", placeholder: "www.yourstore.com", required: true, max_length: 50 },
    { name: "phone", type: "text", label: "Phone", placeholder: "(555) 123-4567", required: false, max_length: 20 },
    { name: "terms", type: "textarea", label: "Terms & Conditions", placeholder: "Some restrictions apply...", required: false, max_length: 150, rows: 2 }
  ],
  default_values: {
    headline: "50% OFF",
    subheadline: "Summer Sale",
    body_text: "Save on all summer items",
    cta_text: "Shop Now",
    offer_details: "Get 50% off all summer clothing and accessories. Huge savings on everything in store and online!",
    expiration_date: "Limited Time",
    terms: "Cannot be combined with other offers. While supplies last."
  }
)

puts "  ✓ Created: Bold Offer"

# Template 2: Product Showcase
PostcardTemplate.create!(
  name: "Product Showcase",
  slug: "product-showcase",
  category: "product",
  description: "Highlight a single product with stunning visuals. Perfect for product launches and featured items.",
  sort_order: 2,
  front_html: <<~HTML,
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
          background: {{color_background}};
          display: flex;
          align-items: center;
          justify-content: center;
          position: relative;
          padding: 80px;
        }
        .logo {
          position: absolute;
          top: 50px;
          right: 50px;
          max-width: 250px;
          max-height: 120px;
        }
        .product-image {
          width: 800px;
          height: 800px;
          object-fit: contain;
          position: absolute;
          left: 100px;
          top: 275px;
        }
        .content {
          position: absolute;
          right: 100px;
          top: 200px;
          width: 700px;
          text-align: right;
        }
        .product-name {
          font-size: 100px;
          font-weight: 800;
          color: {{color_heading}};
          line-height: 1.1;
          margin-bottom: 30px;
        }
        .tagline {
          font-size: 52px;
          color: {{color_text}};
          margin-bottom: 40px;
          line-height: 1.3;
        }
        .price {
          font-size: 120px;
          font-weight: 900;
          color: {{color_accent}};
          margin-bottom: 40px;
        }
        .cta {
          font-size: 56px;
          font-weight: 700;
          background: {{color_cta_bg}};
          color: {{color_cta_text}};
          padding: 30px 70px;
          border-radius: 15px;
          display: inline-block;
        }
      </style>
    </head>
    <body>
      <img src="{{logo_url}}" class="logo" alt="Logo" onerror="this.style.display='none'" />
      <img src="{{product_image_url}}" class="product-image" alt="Product" />
      <div class="content">
        <div class="product-name">{{product_name}}</div>
        <div class="tagline">{{tagline}}</div>
        <div class="price">{{price}}</div>
        <div class="cta">{{cta_text}}</div>
      </div>
    </body>
    </html>
  HTML
  back_html: <<~HTML,
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
          background: #FFFFFF;
          padding: 80px;
        }
        .message-area {
          width: 850px;
          float: left;
        }
        .description {
          font-size: 44px;
          color: #2D3748;
          line-height: 1.5;
          margin-bottom: 50px;
        }
        .features {
          font-size: 38px;
          color: #4A5568;
          line-height: 1.8;
          margin-bottom: 50px;
        }
        .features-title {
          font-weight: 700;
          color: {{color_primary}};
          margin-bottom: 20px;
        }
        .feature-item {
          margin-bottom: 15px;
          padding-left: 40px;
        }
        .contact {
          font-size: 40px;
          color: {{color_primary}};
          font-weight: 600;
          margin-bottom: 20px;
        }
      </style>
    </head>
    <body>
      <div class="message-area">
        <div class="description">{{description}}</div>
        <div class="features">
          <div class="features-title">Key Features:</div>
          <div class="feature-item">✓ {{feature_1}}</div>
          <div class="feature-item">✓ {{feature_2}}</div>
          <div class="feature-item">✓ {{feature_3}}</div>
        </div>
        <div class="contact">🌐 {{website}}</div>
      </div>
    </body>
    </html>
  HTML
  front_fields: [
    { name: "product_image_url", type: "url", label: "Product Image URL", placeholder: "https://...", required: true },
    { name: "product_name", type: "text", label: "Product Name", placeholder: "Amazing Product", required: true, max_length: 30 },
    { name: "tagline", type: "text", label: "Tagline", placeholder: "The best product ever made", required: false, max_length: 60 },
    { name: "price", type: "text", label: "Price", placeholder: "$99", required: true, max_length: 15 },
    { name: "cta_text", type: "text", label: "Call to Action", placeholder: "Buy Now", required: true, max_length: 15 },
    { name: "logo_url", type: "url", label: "Logo URL", placeholder: "https://...", required: false }
  ],
  back_fields: [
    { name: "description", type: "textarea", label: "Product Description", placeholder: "Discover our amazing new product...", required: true, max_length: 180, rows: 3 },
    { name: "feature_1", type: "text", label: "Feature 1", placeholder: "Premium quality materials", required: true, max_length: 50 },
    { name: "feature_2", type: "text", label: "Feature 2", placeholder: "30-day money-back guarantee", required: true, max_length: 50 },
    { name: "feature_3", type: "text", label: "Feature 3", placeholder: "Free shipping nationwide", required: true, max_length: 50 },
    { name: "website", type: "text", label: "Website", placeholder: "www.yourstore.com", required: true, max_length: 50 }
  ],
  default_values: {
    product_name: "New Product",
    tagline: "Premium quality you can trust",
    price: "$99",
    cta_text: "Buy Now",
    description: "Discover our latest innovation designed to make your life easier and more enjoyable.",
    feature_1: "Premium quality materials",
    feature_2: "30-day money-back guarantee",
    feature_3: "Free shipping nationwide"
  }
)

puts "  ✓ Created: Product Showcase"

# Template 3: Event Invitation
PostcardTemplate.create!(
  name: "Event Invitation",
  slug: "event-invitation",
  category: "event",
  description: "Beautiful event invitations for grand openings, workshops, and special occasions.",
  sort_order: 3,
  front_html: <<~HTML,
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 1800px;
          height: 1350px;
          font-family: 'Georgia', serif;
          background: {{color_background}};
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          padding: 120px;
          position: relative;
          border: 30px solid {{color_accent}};
        }
        .logo {
          position: absolute;
          top: 80px;
          left: 80px;
          max-width: 280px;
          max-height: 140px;
        }
        .content {
          z-index: 10;
        }
        .invitation-text {
          font-size: 56px;
          color: {{color_text}};
          margin-bottom: 40px;
          font-style: italic;
        }
        .event-name {
          font-size: 120px;
          font-weight: 700;
          color: {{color_heading}};
          line-height: 1.2;
          margin-bottom: 50px;
        }
        .date-time {
          font-size: 64px;
          color: {{color_primary}};
          font-weight: 600;
          margin-bottom: 30px;
        }
        .location {
          font-size: 56px;
          color: {{color_text}};
          margin-bottom: 60px;
        }
        .cta {
          font-size: 52px;
          font-weight: 700;
          background: {{color_cta_bg}};
          color: {{color_cta_text}};
          padding: 28px 80px;
          border-radius: 12px;
          display: inline-block;
        }
      </style>
    </head>
    <body>
      <img src="{{logo_url}}" class="logo" alt="Logo" onerror="this.style.display='none'" />
      <div class="content">
        <div class="invitation-text">You're Invited to</div>
        <div class="event-name">{{event_name}}</div>
        <div class="date-time">📅 {{date_time}}</div>
        <div class="location">📍 {{location}}</div>
        <div class="cta">{{cta_text}}</div>
      </div>
    </body>
    </html>
  HTML
  back_html: <<~HTML,
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 1800px;
          height: 1350px;
          font-family: 'Georgia', serif;
          background: #FFFFFF;
          padding: 80px;
        }
        .message-area {
          width: 850px;
          float: left;
        }
        .event-details {
          font-size: 42px;
          color: #2D3748;
          line-height: 1.6;
          margin-bottom: 50px;
        }
        .what-to-expect {
          font-size: 38px;
          color: #4A5568;
          line-height: 1.7;
          margin-bottom: 50px;
        }
        .section-title {
          font-weight: 700;
          color: {{color_primary}};
          margin-bottom: 25px;
        }
        .rsvp {
          font-size: 40px;
          color: {{color_accent}};
          font-weight: 700;
          margin-bottom: 30px;
          padding: 25px;
          background: #FFF9E6;
          border-left: 6px solid {{color_accent}};
        }
        .contact {
          font-size: 36px;
          color: #2D3748;
          margin-bottom: 15px;
        }
      </style>
    </head>
    <body>
      <div class="message-area">
        <div class="event-details">{{event_details}}</div>
        <div class="what-to-expect">
          <div class="section-title">What to Expect:</div>
          {{what_to_expect}}
        </div>
        <div class="rsvp">RSVP: {{rsvp_instructions}}</div>
        <div class="contact">🌐 {{website}}</div>
        <div class="contact">📞 {{phone}}</div>
      </div>
    </body>
    </html>
  HTML
  front_fields: [
    { name: "event_name", type: "text", label: "Event Name", placeholder: "Grand Opening", required: true, max_length: 40 },
    { name: "date_time", type: "text", label: "Date & Time", placeholder: "Saturday, Dec 15 at 6 PM", required: true, max_length: 50 },
    { name: "location", type: "text", label: "Location", placeholder: "123 Main St, Your City", required: true, max_length: 60 },
    { name: "cta_text", type: "text", label: "Call to Action", placeholder: "RSVP Now", required: true, max_length: 15 },
    { name: "logo_url", type: "url", label: "Logo URL", placeholder: "https://...", required: false }
  ],
  back_fields: [
    { name: "event_details", type: "textarea", label: "Event Details", placeholder: "Join us for an unforgettable evening...", required: true, max_length: 180, rows: 3 },
    { name: "what_to_expect", type: "textarea", label: "What to Expect", placeholder: "• Live music • Food & drinks • Special guests", required: true, max_length: 150, rows: 3 },
    { name: "rsvp_instructions", type: "text", label: "RSVP Instructions", placeholder: "Call or visit our website", required: true, max_length: 60 },
    { name: "website", type: "text", label: "Website", placeholder: "www.yourevent.com", required: true, max_length: 50 },
    { name: "phone", type: "text", label: "Phone", placeholder: "(555) 123-4567", required: false, max_length: 20 }
  ],
  default_values: {
    event_name: "Grand Opening",
    date_time: "Saturday, December 15 at 6 PM",
    location: "123 Main Street, Your City",
    cta_text: "RSVP Now",
    event_details: "Join us for an unforgettable evening celebrating our grand opening. Meet our team, enjoy refreshments, and be the first to experience what we have to offer!",
    what_to_expect: "• Live music and entertainment\n• Complimentary food and beverages\n• Exclusive opening day discounts\n• Raffles and giveaways",
    rsvp_instructions: "Call us or visit our website by Dec 10"
  }
)

puts "  ✓ Created: Event Invitation"

# Template 4: Welcome/Thank You
PostcardTemplate.create!(
  name: "Welcome/Thank You",
  slug: "welcome-thank-you",
  category: "welcome",
  description: "Build relationships with warm, personal messages. Perfect for new customers and appreciation notes.",
  sort_order: 4,
  front_html: <<~HTML,
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 1800px;
          height: 1350px;
          font-family: 'Georgia', serif;
          background: {{color_background}};
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          padding: 150px;
          position: relative;
        }
        .logo {
          position: absolute;
          top: 70px;
          left: 50%;
          transform: translateX(-50%);
          max-width: 350px;
          max-height: 160px;
        }
        .content {
          z-index: 10;
        }
        .greeting {
          font-size: 80px;
          color: {{color_primary}};
          margin-bottom: 60px;
          font-weight: 600;
        }
        .main-message {
          font-size: 70px;
          color: {{color_heading}};
          line-height: 1.4;
          margin-bottom: 60px;
          font-style: italic;
        }
        .signature {
          font-size: 58px;
          color: {{color_text}};
          margin-top: 80px;
        }
        .company-name {
          font-size: 52px;
          color: {{color_primary}};
          font-weight: 600;
          margin-top: 20px;
        }
      </style>
    </head>
    <body>
      <img src="{{logo_url}}" class="logo" alt="Logo" onerror="this.style.display='none'" />
      <div class="content">
        <div class="greeting">{{greeting}}</div>
        <div class="main-message">{{main_message}}</div>
        <div class="signature">{{signature}}</div>
        <div class="company-name">{{company_name}}</div>
      </div>
    </body>
    </html>
  HTML
  back_html: <<~HTML,
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          width: 1800px;
          height: 1350px;
          font-family: 'Georgia', serif;
          background: #FFFFFF;
          padding: 80px;
        }
        .message-area {
          width: 850px;
          float: left;
        }
        .secondary-message {
          font-size: 44px;
          color: #2D3748;
          line-height: 1.6;
          margin-bottom: 50px;
        }
        .next-steps {
          font-size: 40px;
          color: #4A5568;
          line-height: 1.7;
          margin-bottom: 50px;
          padding: 30px;
          background: #F7FAFC;
          border-radius: 10px;
        }
        .next-steps-title {
          font-weight: 700;
          color: {{color_primary}};
          margin-bottom: 25px;
        }
        .contact {
          font-size: 40px;
          color: {{color_primary}};
          font-weight: 600;
          margin-bottom: 20px;
        }
        .social {
          font-size: 36px;
          color: #4A5568;
          margin-top: 40px;
        }
      </style>
    </head>
    <body>
      <div class="message-area">
        <div class="secondary-message">{{secondary_message}}</div>
        <div class="next-steps">
          <div class="next-steps-title">Next Steps:</div>
          {{next_steps}}
        </div>
        <div class="contact">🌐 {{website}}</div>
        <div class="contact">📞 {{phone}}</div>
        <div class="social">Follow us: {{social_media}}</div>
      </div>
    </body>
    </html>
  HTML
  front_fields: [
    { name: "greeting", type: "text", label: "Greeting", placeholder: "Welcome, {{first_name}}!", required: true, max_length: 40 },
    { name: "main_message", type: "textarea", label: "Main Message", placeholder: "We're so glad you're here...", required: true, max_length: 120, rows: 3 },
    { name: "signature", type: "text", label: "Signature", placeholder: "With gratitude,", required: false, max_length: 30 },
    { name: "company_name", type: "text", label: "Company Name", placeholder: "Your Company", required: true, max_length: 40 },
    { name: "logo_url", type: "url", label: "Logo URL", placeholder: "https://...", required: false }
  ],
  back_fields: [
    { name: "secondary_message", type: "textarea", label: "Secondary Message", placeholder: "We look forward to serving you...", required: true, max_length: 180, rows: 3 },
    { name: "next_steps", type: "textarea", label: "Next Steps", placeholder: "1. Visit our website\n2. Follow us on social media", required: true, max_length: 150, rows: 3 },
    { name: "website", type: "text", label: "Website", placeholder: "www.yourcompany.com", required: true, max_length: 50 },
    { name: "phone", type: "text", label: "Phone", placeholder: "(555) 123-4567", required: false, max_length: 20 },
    { name: "social_media", type: "text", label: "Social Media", placeholder: "@yourcompany", required: false, max_length: 60 }
  ],
  default_values: {
    greeting: "Welcome!",
    main_message: "We're thrilled to have you as part of our community. Thank you for choosing us!",
    signature: "With gratitude,",
    company_name: "Your Company",
    secondary_message: "We're committed to providing you with exceptional service and products. Your satisfaction is our top priority.",
    next_steps: "1. Visit our website to explore our full catalog\n2. Follow us on social media for exclusive updates\n3. Contact us anytime with questions"
  }
)

puts "  ✓ Created: Welcome/Thank You"

# Template 5: Seasonal/Holiday
PostcardTemplate.create!(
  name: "Seasonal/Holiday",
  slug: "seasonal-holiday",
  category: "seasonal",
  description: "Festive designs for holiday promotions and seasonal campaigns. Easily customizable for any holiday.",
  sort_order: 5,
  front_html: <<~HTML,
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
          background: {{color_background}};
          background-image: radial-gradient(circle at 20% 30%, {{color_accent}} 0%, transparent 50%),
                            radial-gradient(circle at 80% 70%, {{color_secondary}} 0%, transparent 50%);
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          padding: 100px;
          position: relative;
        }
        .logo {
          position: absolute;
          top: 60px;
          right: 60px;
          max-width: 280px;
          max-height: 140px;
        }
        .content {
          z-index: 10;
        }
        .season {
          font-size: 70px;
          color: {{color_text}};
          margin-bottom: 30px;
          font-weight: 500;
          letter-spacing: 8px;
        }
        .headline {
          font-size: 160px;
          font-weight: 900;
          color: {{color_heading}};
          line-height: 1;
          margin-bottom: 40px;
          text-shadow: 3px 3px 10px rgba(0,0,0,0.2);
        }
        .offer {
          font-size: 90px;
          font-weight: 700;
          color: {{color_primary}};
          margin-bottom: 50px;
        }
        .dates {
          font-size: 52px;
          color: {{color_text}};
          margin-bottom: 60px;
        }
        .cta {
          font-size: 62px;
          font-weight: 800;
          background: {{color_cta_bg}};
          color: {{color_cta_text}};
          padding: 32px 85px;
          border-radius: 18px;
          display: inline-block;
          text-transform: uppercase;
          box-shadow: 0 6px 18px rgba(0,0,0,0.25);
        }
      </style>
    </head>
    <body>
      <img src="{{logo_url}}" class="logo" alt="Logo" onerror="this.style.display='none'" />
      <div class="content">
        <div class="season">{{season}}</div>
        <div class="headline">{{headline}}</div>
        <div class="offer">{{offer}}</div>
        <div class="dates">{{dates}}</div>
        <div class="cta">{{cta_text}}</div>
      </div>
    </body>
    </html>
  HTML
  back_html: <<~HTML,
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
          background: #FFFFFF;
          padding: 80px;
        }
        .message-area {
          width: 850px;
          float: left;
        }
        .offer-details {
          font-size: 44px;
          color: #2D3748;
          line-height: 1.6;
          margin-bottom: 50px;
        }
        .highlights {
          font-size: 40px;
          color: #4A5568;
          line-height: 1.8;
          margin-bottom: 50px;
          padding: 30px;
          background: #FFF9E6;
          border-radius: 10px;
        }
        .highlights-title {
          font-weight: 700;
          color: {{color_primary}};
          margin-bottom: 20px;
        }
        .dates-box {
          font-size: 38px;
          color: #E53E3E;
          font-weight: 700;
          margin-bottom: 50px;
          padding: 25px;
          background: #FFF5F5;
          border-left: 6px solid #E53E3E;
        }
        .contact {
          font-size: 40px;
          color: {{color_primary}};
          font-weight: 600;
          margin-bottom: 20px;
        }
        .terms {
          font-size: 26px;
          color: #718096;
          margin-top: 40px;
          line-height: 1.5;
        }
      </style>
    </head>
    <body>
      <div class="message-area">
        <div class="offer-details">{{offer_details}}</div>
        <div class="highlights">
          <div class="highlights-title">🎁 Special Features:</div>
          {{highlights}}
        </div>
        <div class="dates-box">⏰ {{dates}}</div>
        <div class="contact">🌐 {{website}}</div>
        <div class="contact">📞 {{phone}}</div>
        <div class="terms">{{terms}}</div>
      </div>
    </body>
    </html>
  HTML
  front_fields: [
    { name: "season", type: "text", label: "Season/Holiday", placeholder: "HOLIDAY SALE", required: true, max_length: 20 },
    { name: "headline", type: "text", label: "Headline", placeholder: "BIG SAVINGS", required: true, max_length: 20 },
    { name: "offer", type: "text", label: "Offer", placeholder: "Up to 70% Off", required: true, max_length: 30 },
    { name: "dates", type: "text", label: "Dates", placeholder: "Dec 20-26", required: true, max_length: 30 },
    { name: "cta_text", type: "text", label: "Call to Action", placeholder: "Shop Now", required: true, max_length: 15 },
    { name: "logo_url", type: "url", label: "Logo URL", placeholder: "https://...", required: false }
  ],
  back_fields: [
    { name: "offer_details", type: "textarea", label: "Offer Details", placeholder: "Celebrate the season with amazing savings...", required: true, max_length: 180, rows: 3 },
    { name: "highlights", type: "textarea", label: "Highlights", placeholder: "• Storewide savings\n• Gift wrapping included", required: true, max_length: 150, rows: 3 },
    { name: "website", type: "text", label: "Website", placeholder: "www.yourstore.com", required: true, max_length: 50 },
    { name: "phone", type: "text", label: "Phone", placeholder: "(555) 123-4567", required: false, max_length: 20 },
    { name: "terms", type: "textarea", label: "Terms", placeholder: "Some exclusions apply...", required: false, max_length: 120, rows: 2 }
  ],
  default_values: {
    season: "HOLIDAY SALE",
    headline: "Big Savings",
    offer: "Up to 70% Off",
    dates: "Limited Time Only",
    cta_text: "Shop Now",
    offer_details: "Celebrate the season with incredible savings on everything you love. Don't miss out on these spectacular holiday deals!",
    highlights: "• Storewide savings up to 70% off\n• Free gift wrapping on all purchases\n• Extended holiday hours\n• Easy returns through January"
  }
)

puts "  ✓ Created: Seasonal/Holiday"

puts "✅ Successfully seeded #{PostcardTemplate.count} postcard templates!"

