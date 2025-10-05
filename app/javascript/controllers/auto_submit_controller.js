import { Controller } from "@hotwired/stimulus"

// Auto-submit forms when inputs change
export default class extends Controller {
  submit(event) {
    // Let the change event bubble up first
    setTimeout(() => {
      this.element.requestSubmit()
    }, 10)
  }
}

