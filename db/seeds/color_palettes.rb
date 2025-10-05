# Color Palettes Seed Data
# Creates 5 professional color palettes that work beautifully with all templates

puts "🎨 Seeding Color Palettes..."

# Clear existing palettes (only in development)
if Rails.env.development?
  ColorPalette.where(advertiser_id: nil).destroy_all
  puts "  ✓ Cleared existing global palettes"
end

# Palette 1: Vibrant (Red/Orange - High Energy)
ColorPalette.create!(
  name: "Vibrant",
  slug: "vibrant",
  is_default: true,
  colors: {
    primary: "#E53E3E",      # Bright red
    secondary: "#F56565",    # Lighter red
    accent: "#FF6B35",       # Orange accent
    background: "#FFFFFF",   # White
    text: "#2D3748",         # Dark gray
    heading: "#1A202C",      # Almost black
    cta_bg: "#E53E3E",       # Bright red
    cta_text: "#FFFFFF"      # White
  }
)

puts "  ✓ Created: Vibrant (Red/Orange)"

# Palette 2: Professional (Blue/Gray - Corporate)
ColorPalette.create!(
  name: "Professional",
  slug: "professional",
  is_default: false,
  colors: {
    primary: "#2B6CB0",      # Professional blue
    secondary: "#4299E1",    # Lighter blue
    accent: "#3182CE",       # Medium blue
    background: "#F7FAFC",   # Light gray
    text: "#4A5568",         # Medium gray
    heading: "#1A202C",      # Almost black
    cta_bg: "#2B6CB0",       # Professional blue
    cta_text: "#FFFFFF"      # White
  }
)

puts "  ✓ Created: Professional (Blue/Gray)"

# Palette 3: Natural (Green/Brown - Organic)
ColorPalette.create!(
  name: "Natural",
  slug: "natural",
  is_default: false,
  colors: {
    primary: "#38A169",      # Forest green
    secondary: "#48BB78",    # Lighter green
    accent: "#9AE6B4",       # Mint accent
    background: "#FFFFF0",   # Ivory
    text: "#2D3748",         # Dark gray
    heading: "#22543D",      # Deep green
    cta_bg: "#38A169",       # Forest green
    cta_text: "#FFFFFF"      # White
  }
)

puts "  ✓ Created: Natural (Green/Brown)"

# Palette 4: Elegant (Purple/Gold - Luxury)
ColorPalette.create!(
  name: "Elegant",
  slug: "elegant",
  is_default: false,
  colors: {
    primary: "#6B46C1",      # Royal purple
    secondary: "#9F7AEA",    # Lighter purple
    accent: "#D69E2E",       # Gold
    background: "#FAF5FF",   # Light purple
    text: "#4A5568",         # Medium gray
    heading: "#44337A",      # Deep purple
    cta_bg: "#6B46C1",       # Royal purple
    cta_text: "#FFFFFF"      # White
  }
)

puts "  ✓ Created: Elegant (Purple/Gold)"

# Palette 5: Bold (High Contrast - Modern)
ColorPalette.create!(
  name: "Bold",
  slug: "bold",
  is_default: false,
  colors: {
    primary: "#000000",      # Black
    secondary: "#2D3748",    # Dark gray
    accent: "#ECC94B",       # Yellow accent
    background: "#FFFFFF",   # White
    text: "#1A202C",         # Almost black
    heading: "#000000",      # Black
    cta_bg: "#000000",       # Black
    cta_text: "#ECC94B"      # Yellow
  }
)

puts "  ✓ Created: Bold (High Contrast)"

puts "✅ Successfully seeded #{ColorPalette.count} color palettes!"

