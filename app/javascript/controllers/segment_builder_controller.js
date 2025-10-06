import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "filter"]
  static values = { previewUrl: String }

  connect() {
    // Auto-load preview on connect if we have existing filters
    const hasFilters = Array.from(this.filterTargets).some(filter => {
      const value = filter.value
      return value && value.trim() !== ''
    })
    
    if (hasFilters) {
      this.updatePreview()
    }
  }

  async updatePreview() {
    this.previewTarget.innerHTML = '<div class="text-sm text-gray-500">Loading...</div>'
    
    try {
      // Collect all filter values
      const filters = {}
      this.filterTargets.forEach(filter => {
        const name = filter.name.match(/\[(\w+)\]$/)?.[1]
        if (name && filter.value) {
          filters[name] = filter.value
        }
      })
      
      // Build query string
      const params = new URLSearchParams()
      Object.entries(filters).forEach(([key, value]) => {
        params.append(`filters[${key}]`, value)
      })
      
      const response = await fetch(`${this.previewUrlValue}?${params.toString()}`)
      const data = await response.json()
      
      if (data.count > 0) {
        this.previewTarget.innerHTML = `
          <div>
            <div class="text-3xl font-bold text-gray-950 mb-2">${data.count.toLocaleString()}</div>
            <p class="text-sm text-gray-600">contacts match your criteria</p>
          </div>
        `
      } else {
        this.previewTarget.innerHTML = '<div class="text-sm text-gray-500">No contacts match your criteria</div>'
      }
    } catch (error) {
      console.error('Error loading preview:', error)
      this.previewTarget.innerHTML = '<div class="text-sm text-red-600">Error loading preview</div>'
    }
  }
}

