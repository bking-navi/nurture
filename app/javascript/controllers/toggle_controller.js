import { Controller } from "@hotwired/stimulus"

// Toggle visibility of content
export default class extends Controller {
  static targets = ["content", "button"]
  
  toggle() {
    this.contentTarget.classList.toggle("hidden")
    
    if (this.hasButtonTarget) {
      const isHidden = this.contentTarget.classList.contains("hidden")
      this.buttonTarget.textContent = isHidden
        ? "+ Show more fields"
        : "− Show fewer fields"
    }
  }
}

