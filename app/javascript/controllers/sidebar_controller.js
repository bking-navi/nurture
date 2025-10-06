import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "content"]

  connect() {
    // Disable transitions for initial setup
    const originalTransition = this.sidebarTarget.style.transition
    this.sidebarTarget.style.transition = 'none'
    
    // Set initial state based on screen size
    const isMobile = window.innerWidth < 1024
    
    if (isMobile) {
      // Mobile: start hidden
      this.sidebarTarget.classList.add("-translate-x-full")
    } else {
      // Desktop: start visible
      this.sidebarTarget.classList.remove("-translate-x-full")
    }
    
    // Re-enable transitions after a frame
    requestAnimationFrame(() => {
      this.sidebarTarget.style.transition = originalTransition
    })
  }

  toggle(event) {
    event.preventDefault()
    const isHidden = this.sidebarTarget.classList.contains("-translate-x-full")
    
    if (isHidden) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    // Show sidebar
    this.sidebarTarget.classList.remove("-translate-x-full")
    
    const isMobile = window.innerWidth < 1024
    
    if (isMobile) {
      // Mobile: show overlay and prevent scroll
      this.overlayTarget.classList.remove("hidden")
      document.body.style.overflow = "hidden"
    } else {
      // Desktop: add margin to content
      this.contentTarget.classList.add("lg:ml-64")
    }
  }

  hide() {
    // Hide sidebar
    this.sidebarTarget.classList.add("-translate-x-full")
    
    const isMobile = window.innerWidth < 1024
    
    if (isMobile) {
      // Mobile: hide overlay and restore scroll
      this.overlayTarget.classList.add("hidden")
      document.body.style.overflow = ""
    } else {
      // Desktop: remove margin from content
      this.contentTarget.classList.remove("lg:ml-64")
    }
  }

  disconnect() {
    // Clean up when controller is disconnected
    document.body.style.overflow = ""
  }
}

