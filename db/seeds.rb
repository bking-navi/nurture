# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "\n🌱 Starting database seeding...\n\n"

# Load color palettes first (no dependencies)
load Rails.root.join('db', 'seeds', 'color_palettes.rb')

# Load postcard templates (no dependencies)
load Rails.root.join('db', 'seeds', 'postcard_templates.rb')

puts "\n✅ All seeds completed successfully!\n\n"
