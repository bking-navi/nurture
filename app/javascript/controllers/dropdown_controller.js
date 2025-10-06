import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    // Bind the hide method to this instance so we can add/remove it as a listener
    this.boundHide = this.hide.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.menuTarget.classList.contains("hidden")
    
    if (isHidden) {
      this.menuTarget.classList.remove("hidden")
      // Add click listener to document to close on outside click
      setTimeout(() => {
        document.addEventListener("click", this.boundHide)
      }, 0)
    } else {
      this.menuTarget.classList.add("hidden")
      document.removeEventListener("click", this.boundHide)
    }
  }

  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
      document.removeEventListener("click", this.boundHide)
    }
  }

  disconnect() {
    // Clean up the event listener when controller is disconnected
    document.removeEventListener("click", this.boundHide)
  }
}

