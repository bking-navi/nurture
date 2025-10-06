import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  open(event) {
    event.preventDefault()
    this.modalTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close(event) {
    event.preventDefault()
    this.modalTarget.classList.add("hidden")
    document.body.style.overflow = "auto"
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}

