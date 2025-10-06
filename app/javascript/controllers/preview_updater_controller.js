// app/javascript/controllers/preview_updater_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview"]
  static values = { 
    url: String,
    advertiserSlug: String,
    campaignId: String
  }
  
  connect() {
    this.timeout = null
    this.currentSide = 'front'
    
    // Load initial preview
    setTimeout(() => this.fetchPreview(), 100)
  }
  
  update() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.fetchPreview()
    }, 300) // 300ms debounce
  }
  
  setSide(event) {
    this.currentSide = event.target.dataset.side
    this.updateSideButtons()
    this.fetchPreview()
  }
  
  updateSideButtons() {
    // Update button active states
    const buttons = document.querySelectorAll('[data-side]')
    buttons.forEach(btn => {
      if (btn.dataset.side === this.currentSide) {
        btn.classList.remove('bg-gray-200', 'text-gray-700')
        btn.classList.add('bg-indigo-100', 'text-indigo-700')
      } else {
        btn.classList.remove('bg-indigo-100', 'text-indigo-700')
        btn.classList.add('bg-gray-200', 'text-gray-700')
      }
    })
  }
  
  async fetchPreview() {
    if (!this.hasPreviewTarget) {
      console.log('No preview target found')
      return
    }
    
    // Find the form (should be a direct child of this.element)
    const form = this.element.querySelector('form')
    if (!form) {
      console.error('No form found for preview')
      return
    }
    
    // Build URL
    const previewUrl = `/advertisers/${this.advertiserSlugValue}/campaigns/${this.campaignIdValue}/preview_live`
    
    // Get form data
    const formData = new FormData(form)
    const params = new URLSearchParams()
    
    // Add side
    params.append('side', this.currentSide)
    
    // Add template and palette IDs
    const templateId = formData.get('campaign[postcard_template_id]')
    const paletteId = formData.get('campaign[color_palette_id]')
    
    if (templateId) params.append('postcard_template_id', templateId)
    if (paletteId) params.append('color_palette_id', paletteId)
    
    // Add all template_data fields
    for (let [key, value] of formData.entries()) {
      if (key.startsWith('campaign[template_data]')) {
        params.append(key, value)
      }
    }
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    
    try {
      const response = await fetch(previewUrl, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'text/html'
        },
        body: params.toString()
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      
      const html = await response.text()
      
      // Find the iframe inside preview target
      const iframe = this.previewTarget.querySelector('iframe')
      if (iframe) {
        iframe.srcdoc = html
      } else {
        console.error('No iframe found in preview target')
      }
    } catch (error) {
      console.error('Preview failed:', error)
      const iframe = this.previewTarget.querySelector('iframe')
      if (iframe) {
        iframe.srcdoc = '<div style="padding: 40px; text-align: center; color: #e53e3e; font-family: sans-serif;">Preview failed to load</div>'
      }
    }
  }
}
