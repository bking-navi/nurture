# Creative Library Specification

**Version:** 1.0  
**Date:** October 6, 2025  
**Status:** Ready for Implementation

---

## Overview

A creative asset management system that allows users to upload, organize, and reuse postcard designs across campaigns. Creatives are stored independently of campaigns and can be selected when creating new campaigns, eliminating duplicate uploads and speeding up campaign creation.

---

## Core Requirements

### Philosophy
- **Simple asset library** - no complex editor, just upload & reuse
- **Campaign-independent** - creatives live beyond individual campaigns
- **Team-friendly** - shared across entire advertiser account
- **Fast workflow** - find and reuse proven winners quickly

---

## 1. Data Model

### `Creative` Table

```ruby
create_table :creatives do |t|
  t.references :advertiser, null: false, foreign_key: true
  t.references :postcard_template, null: false, foreign_key: true
  t.references :created_by_user, foreign_key: { to_table: :users }
  t.references :created_from_campaign, foreign_key: { to_table: :campaigns }
  
  t.string :name, null: false
  t.text :description
  t.string :tags, array: true, default: []
  t.integer :usage_count, default: 0
  t.datetime :last_used_at
  t.string :status, default: 'active' # active, archived
  
  t.timestamps
end

# Active Storage Attachments (via has_one_attached)
- front_pdf (required)
- back_pdf (optional)
- thumbnail (auto-generated from front_pdf)

add_index :creatives, [:advertiser_id, :status]
add_index :creatives, [:advertiser_id, :tags], using: 'gin'
add_index :creatives, :usage_count
```

### Campaign Model Changes

```ruby
# Add to campaigns table
add_column :campaigns, :creative_id, :bigint, foreign_key: true

# Campaign model
belongs_to :creative, optional: true
has_one_attached :front_pdf # fallback for one-off uploads
has_one_attached :back_pdf  # fallback for one-off uploads

# Helper methods
def front_pdf_file
  creative&.front_pdf || front_pdf
end

def back_pdf_file
  creative&.back_pdf || back_pdf || creative&.postcard_template&.default_back_pdf
end
```

### Business Rules

1. **Ownership:** Creatives belong to an Advertiser (not individual users)
2. **Access:** Any user with access to the Advertiser can view/use all creatives
3. **Editing:** Users can update creative files/metadata even after use in campaigns
4. **Deletion:** Creatives can be deleted, but campaigns that used them retain their own PDF copies
5. **Back PDF:** Optional - if not provided, campaign uses template default
6. **Tags:** Freeform text array - users can add any tags they want
7. **Usage Tracking:** Increments when campaign is created (not on draft save)

---

## 2. User Flows

### Flow A: Upload Creative to Library

**Route:** `/advertisers/{slug}/creatives/new`

**Form Fields:**
```
Name*:              [Summer Sale 20% Off         ]
Description:        [Converts well with Champions segment]
Postcard Size*:     [6x9 Postcard ▾]
Front Design*:      [Choose File] summer-front.pdf
Back Design:        [Choose File] summer-back.pdf (optional)
Tags:               [winback] [seasonal] [+ Add tag]
```

**Validation:**
- Name required (max 100 chars)
- Front PDF required
- Back PDF optional
- Size required (from postcard_templates)
- Tags optional (comma-separated on submit)

**After Save:**
- Generate thumbnail from front PDF
- Redirect to creative detail page
- Show success message: "Creative saved to library"

---

### Flow B: Browse Creative Library

**Route:** `/advertisers/{slug}/creatives`

**Layout:** Responsive grid

**Header:**
```
┌────────────────────────────────────────────────┐
│ Creatives (23)              [+ New Creative]   │
└────────────────────────────────────────────────┘
```

**Filters:**
```
[🔍 Search creatives...] [6x9 ▾] [Tags ▾] [Sort: Recent ▾]
```

**Grid Cards:**
```
┌─────────────────┐
│   [Thumbnail]   │ ← Front PDF preview
│                 │
├─────────────────┤
│ Summer Sale 20% │ ← Name
│ 6x9 • winback   │ ← Size • Tags
│ Used 5 times    │ ← Usage count
│ Mar 15, 2025    │ ← Last used
├─────────────────┤
│ [Edit] [Delete] │ ← Actions
└─────────────────┘
```

**Filter Options:**
- **Search:** Searches name and description
- **Size:** All Sizes, 6x9, 4x6 (from templates)
- **Tags:** Multi-select from all tags used
- **Sort:** Recent (last_used_at), Most Used (usage_count), Name (A-Z)

**Empty State:**
```
No creatives yet
Upload your first postcard design to reuse across campaigns
[+ New Creative]
```

---

### Flow C: Creative Detail Page

**Route:** `/advertisers/{slug}/creatives/{id}`

**Layout:**
```
┌────────────────────────────────────────────────┐
│ ← Back to Creatives         [Edit] [Delete]    │
├────────────────────────────────────────────────┤
│ Summer Sale 20% Off                            │
│ 6x9 Postcard • Used in 5 campaigns             │
├────────────────────────────────────────────────┤
│ ┌──────────────┐  ┌──────────────┐            │
│ │   FRONT      │  │    BACK      │            │
│ │  [Preview]   │  │  [Preview]   │            │
│ │              │  │              │            │
│ └──────────────┘  └──────────────┘            │
│                                                │
│ Description:                                   │
│ Converts well with Champions segment          │
│                                                │
│ Tags: [winback] [seasonal]                     │
│                                                │
│ Created: Mar 1, 2025 by Bryan King            │
│ Last Used: Mar 15, 2025                       │
├────────────────────────────────────────────────┤
│ Campaign Usage History                         │
│ • Spring Sale Campaign - Mar 15, 2025         │
│ • Welcome Back Series - Mar 10, 2025          │
│ • VIP Offer - Feb 28, 2025                    │
└────────────────────────────────────────────────┘
```

**Actions:**
- **Edit:** Update metadata and/or replace PDF files
- **Delete:** Confirm dialog, explain campaigns keep their copies
- **Download:** Download front/back PDFs

---

### Flow D: Use Creative in Campaign

**Route:** `/advertisers/{slug}/campaigns/new` (Design tab)

**Option 1: Upload New (Current Behavior)**
```
Design Source
● Upload New Files

Front Design*: [Choose File] campaign-front.pdf
Back Design*:  [Choose File] campaign-back.pdf

□ Save to Creative Library
  Name: [From Campaign]
  Tags: [Add tags]
```

**Option 2: Select from Library (NEW)**
```
Design Source
○ Use from Library

[🔍 Search library...]  [6x9 ▾]  [Tags ▾]

┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│[Thumbnail]  │ │[Thumbnail]  │ │[Thumbnail]  │
│Summer Sale  │ │Black Friday │ │VIP Thanks   │
│○ Select     │ │○ Select     │ │● Selected   │
└─────────────┘ └─────────────┘ └─────────────┘

Selected: VIP Thanks You
[Preview Full Size]
```

**Form Updates:**
```ruby
# Campaign form
design_source: radio_button (upload_new | use_library)

# If upload_new:
- front_pdf (file upload)
- back_pdf (file upload)
- save_to_library (checkbox)
  - creative_name (text, pre-filled from campaign name)
  - creative_tags (text, suggested from segment)

# If use_library:
- creative_id (hidden field, set by JS)
- Shows creative selector modal/grid
```

**After Campaign Creation:**
- If `creative_id` present:
  - Increment `creative.usage_count`
  - Update `creative.last_used_at`
  - Set `campaign.creative_id`
- If `save_to_library` checked:
  - Create new Creative from uploaded PDFs
  - Link to campaign via `created_from_campaign_id`

---

### Flow E: Edit Creative

**Route:** `/advertisers/{slug}/creatives/{id}/edit`

**Form (same as new, but pre-filled):**
```
Name*:              [Summer Sale 20% Off         ]
Description:        [Converts well with Champions segment]
Postcard Size*:     [6x9 Postcard ▾] (can change)
Front Design*:      [Current: summer-front.pdf]
                    [Replace File]
Back Design:        [Current: summer-back.pdf]
                    [Replace File] or [Remove Back]
Tags:               [winback] [seasonal] [+ Add tag]

[Save Changes] [Cancel]
```

**Warning on File Replace:**
```
⚠️ This creative is used in 5 campaigns
Replacing files won't affect past campaigns (they keep their copies)
Future campaigns using this creative will use the new files.
```

**After Update:**
- Re-generate thumbnail if front PDF changed
- Show success: "Creative updated"
- Redirect to detail page

---

## 3. Technical Implementation

### Thumbnail Generation

```ruby
# app/models/creative.rb
after_commit :generate_thumbnail, if: :front_pdf_attached?

def generate_thumbnail
  return unless front_pdf.attached?
  
  front_pdf.open do |file|
    # Convert PDF first page to PNG using ImageMagick/Poppler
    thumb = MiniMagick::Image.open(file.path)
    thumb.format "png"
    thumb.resize "400x600" # 2:3 aspect ratio
    thumb.quality "85"
    
    # Attach as thumbnail
    thumbnail.attach(
      io: File.open(thumb.path),
      filename: "#{name.parameterize}-thumb.png",
      content_type: "image/png"
    )
  end
end
```

### Usage Tracking

```ruby
# app/models/campaign.rb
after_create :increment_creative_usage, if: :creative_id?

def increment_creative_usage
  creative.increment!(:usage_count)
  creative.touch(:last_used_at)
end
```

### Creative Selection (Stimulus Controller)

```javascript
// app/javascript/controllers/creative_selector_controller.js
export default class extends Controller {
  static targets = ["grid", "selected", "preview"]
  
  select(event) {
    const creativeId = event.currentTarget.dataset.creativeId
    const creativeName = event.currentTarget.dataset.creativeName
    
    // Update hidden field
    this.hiddenField.value = creativeId
    
    // Show selection
    this.selectedTarget.textContent = `Selected: ${creativeName}`
    
    // Highlight in grid
    this.updateSelection(event.currentTarget)
  }
  
  preview(event) {
    // Show modal with full-size front/back preview
  }
}
```

### PDF Handling

```ruby
# When campaign uses creative
def copy_creative_pdfs_to_campaign
  return unless creative
  
  # Campaigns store a reference but also copy PDFs
  # This ensures campaigns are immutable after send
  self.front_pdf.attach(creative.front_pdf.blob) if creative.front_pdf.attached?
  self.back_pdf.attach(creative.back_pdf.blob) if creative.back_pdf.attached?
end
```

---

## 4. Routes

```ruby
scope 'advertisers/:advertiser_slug' do
  resources :creatives do
    member do
      get :preview        # Full-screen preview
      post :duplicate     # Create copy
      patch :archive      # Soft delete
    end
    
    collection do
      get :selector       # Modal/AJAX for campaign creation
    end
  end
  
  resources :campaigns do
    resources :creatives, only: [:create], controller: 'campaign_creatives'
    # POST /campaigns/:id/creatives - save campaign PDFs as creative
  end
end
```

---

## 5. Validations & Business Logic

### Creative Model

```ruby
class Creative < ApplicationRecord
  belongs_to :advertiser
  belongs_to :postcard_template
  belongs_to :created_by_user, class_name: 'User', optional: true
  belongs_to :created_from_campaign, class_name: 'Campaign', optional: true
  
  has_one_attached :front_pdf
  has_one_attached :back_pdf
  has_one_attached :thumbnail
  
  has_many :campaigns
  
  validates :name, presence: true, length: { maximum: 100 }
  validates :front_pdf, presence: true
  validate :front_pdf_is_pdf
  validate :back_pdf_is_pdf, if: :back_pdf_attached?
  
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
  scope :recent, -> { order(last_used_at: :desc, created_at: :desc) }
  scope :popular, -> { order(usage_count: :desc) }
  
  def front_pdf_is_pdf
    return unless front_pdf.attached?
    
    unless front_pdf.content_type == 'application/pdf'
      errors.add(:front_pdf, 'must be a PDF file')
    end
  end
  
  def back_pdf_is_pdf
    return unless back_pdf.attached?
    
    unless back_pdf.content_type == 'application/pdf'
      errors.add(:back_pdf, 'must be a PDF file')
    end
  end
  
  def all_tags
    advertiser.creatives.pluck(:tags).flatten.uniq.sort
  end
end
```

---

## 6. UI Components

### Creative Card (Partial)

```erb
<!-- app/views/creatives/_creative_card.html.erb -->
<div class="bg-white rounded-lg shadow hover:shadow-lg transition">
  <%= link_to creative_path(@advertiser.slug, creative), class: "block" do %>
    <!-- Thumbnail -->
    <div class="aspect-w-2 aspect-h-3 bg-gray-100">
      <% if creative.thumbnail.attached? %>
        <%= image_tag creative.thumbnail, class: "object-cover" %>
      <% else %>
        <div class="flex items-center justify-center">
          <svg class="h-12 w-12 text-gray-400"><!-- PDF icon --></svg>
        </div>
      <% end %>
    </div>
    
    <!-- Info -->
    <div class="p-4">
      <h3 class="font-medium text-gray-900 truncate">
        <%= creative.name %>
      </h3>
      
      <div class="mt-1 text-sm text-gray-500">
        <%= creative.postcard_template.name %>
        <% if creative.tags.any? %>
          • <%= creative.tags.take(2).join(', ') %>
        <% end %>
      </div>
      
      <div class="mt-2 text-sm text-gray-600">
        Used <%= pluralize(creative.usage_count, 'time') %>
        <% if creative.last_used_at %>
          • <%= time_ago_in_words(creative.last_used_at) %> ago
        <% end %>
      </div>
    </div>
  <% end %>
  
  <!-- Actions -->
  <div class="px-4 pb-4 flex gap-2">
    <%= link_to "Edit", edit_creative_path(@advertiser.slug, creative), 
        class: "btn-sm" %>
    <%= button_to "Delete", creative_path(@advertiser.slug, creative), 
        method: :delete, data: { turbo_confirm: "Delete this creative?" },
        class: "btn-sm btn-danger" %>
  </div>
</div>
```

### Creative Selector Modal

```erb
<!-- app/views/creatives/_selector.html.erb -->
<div data-controller="creative-selector">
  <div class="mb-4">
    <input type="search" 
           placeholder="Search creatives..." 
           data-action="input->creative-selector#search"
           class="form-input" />
  </div>
  
  <div class="grid grid-cols-3 gap-4" data-creative-selector-target="grid">
    <% @creatives.each do |creative| %>
      <div class="relative cursor-pointer border-2 rounded-lg"
           data-action="click->creative-selector#select"
           data-creative-id="<%= creative.id %>"
           data-creative-name="<%= creative.name %>">
        
        <%= image_tag creative.thumbnail, class: "w-full" %>
        
        <div class="p-2 text-sm">
          <div class="font-medium"><%= creative.name %></div>
          <div class="text-gray-500"><%= creative.postcard_template.name %></div>
        </div>
        
        <!-- Selection indicator -->
        <div class="hidden absolute top-2 right-2 bg-blue-600 text-white rounded-full p-2"
             data-creative-selector-target="indicator">
          <svg class="h-4 w-4"><!-- Checkmark --></svg>
        </div>
      </div>
    <% end %>
  </div>
  
  <input type="hidden" 
         name="campaign[creative_id]" 
         data-creative-selector-target="hiddenField" />
</div>
```

---

## 7. Migration Plan

### Phase 1: Database & Models ✅
1. Create `creatives` table migration
2. Add `creative_id` to campaigns
3. Create Creative model
4. Update Campaign model associations

### Phase 2: Upload & Library 🎯
1. Build upload form (`creatives#new`)
2. Generate thumbnails on upload
3. Build library grid (`creatives#index`)
4. Build detail page (`creatives#show`)
5. Search & filter functionality

### Phase 3: Campaign Integration
1. Add creative selector to campaign form
2. "Use from Library" option
3. "Save to Library" checkbox for uploads
4. Usage tracking
5. Copy PDFs to campaigns on use

### Phase 4: Management
1. Edit creative (`creatives#edit`)
2. Delete with confirmation
3. Duplicate creative
4. Archive functionality

### Phase 5: Polish
1. Better thumbnail generation
2. Preview modal for full-size view
3. Batch operations (bulk delete, tag)
4. Usage history on detail page

---

## 8. Success Metrics

**Adoption:**
- % of campaigns using library vs. upload
- Avg creatives per advertiser
- Avg reuse per creative

**Efficiency:**
- Time to create campaign (before/after)
- Reduction in duplicate PDF uploads
- Storage savings from deduplication

**Quality:**
- Campaign performance by creative usage count
- Top-performing creatives by segment

---

## 9. Future Enhancements (Out of Scope for v1)

1. **Merge Fields:** Dynamic personalization ({{first_name}}, etc.)
2. **A/B Testing:** Split test creatives automatically
3. **Performance Tracking:** Click rates, conversion by creative
4. **Folders/Categories:** Beyond tags
5. **Versioning:** Track creative iterations
6. **Bulk Upload:** Multiple creatives at once
7. **Smart Suggestions:** Recommend creative based on segment
8. **Visual Editor:** In-app design tool (if needed)
9. **Creative Analytics Dashboard:** Performance metrics
10. **QR Code Generation:** Auto-add tracking codes

---

## 10. Open Questions / Decisions Made

| Question | Decision |
|----------|----------|
| Tags: Freeform or predefined? | **Freeform** - users add any tags |
| Can users edit after use? | **Yes** - edits don't affect past campaigns |
| Back PDF required? | **No** - optional, uses template default if missing |
| Thumbnail source? | **Auto-generate from PDF** (no manual upload) |
| Sharing scope? | **Advertiser-wide** (all team members can access) |
| Organization method? | **Tags only** (no folders for now) |
| Delete used creatives? | **Yes** - campaigns keep their PDF copies |

---

## Conclusion

This spec provides a practical, scalable creative management system focused on **reusability** and **speed**. No complex editor—just smart storage and easy selection. Users can build a library of proven winners and deploy them across segments in seconds.

**Ready to build!** 🚀

