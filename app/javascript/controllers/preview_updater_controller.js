import { Controller } from "@hotwired/stimulus"

// Updates preview iframe as user types
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
    
    // Wait a bit for turbo frame to load, then update preview
    setTimeout(() => {
      if (this.hasPreviewTarget) {
        this.update()
      }
    }, 100)
  }
  
  update() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.fetchPreview()
    }, 300)
  }
  
  async fetchPreview() {
    const form = this.element.closest('form')
    if (!form) return
    
    const formData = new FormData(form)
    const side = this.currentSide || 'front'
    formData.append('side', side)
    
    // Build preview URL
    const url = `/advertisers/${this.advertiserSlugValue}/campaigns/${this.campaignIdValue}/preview_live`
    
    try {
      const response = await fetch(url, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        if (this.hasPreviewTarget) {
          const iframe = this.previewTarget.querySelector('iframe')
          if (iframe) {
            iframe.srcdoc = html
          }
        }
      }
    } catch (error) {
      console.error('Preview update failed:', error)
    }
  }
  
  switchSide(event) {
    const side = event.currentTarget.dataset.side
    this.currentSide = side
    
    // Update button states
    const buttons = this.element.querySelectorAll('[data-side]')
    buttons.forEach(btn => {
      if (btn.dataset.side === side) {
        btn.classList.remove('bg-gray-200', 'text-gray-700')
        btn.classList.add('bg-indigo-100', 'text-indigo-700')
      } else {
        btn.classList.add('bg-gray-200', 'text-gray-700')
        btn.classList.remove('bg-indigo-100', 'text-indigo-700')
      }
    })
    
    this.fetchPreview()
  }
}

