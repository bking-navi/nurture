import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pdf-preview"
export default class extends Controller {
  static targets = ["input", "preview", "previewContainer", "fileName", "fileSize"]
  
  connect() {
    console.log("PDF Preview controller connected")
  }
  
  preview(event) {
    const file = event.target.files[0]
    
    if (!file) {
      this.hidePreview()
      return
    }
    
    // Validate it's a PDF
    if (file.type !== 'application/pdf') {
      alert('Please select a PDF file')
      event.target.value = ''
      return
    }
    
    // Show file info
    if (this.hasFileNameTarget) {
      this.fileNameTarget.textContent = file.name
    }
    
    if (this.hasFileSizeTarget) {
      this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    }
    
    // Create object URL for the PDF
    const objectUrl = URL.createObjectURL(file)
    
    // Update preview iframe or embed
    if (this.hasPreviewTarget) {
      this.previewTarget.src = objectUrl
      
      // Show the preview container
      if (this.hasPreviewContainerTarget) {
        this.previewContainerTarget.classList.remove('hidden')
      }
      
      // Cleanup old object URL when new file is selected
      if (this.currentObjectUrl) {
        URL.revokeObjectURL(this.currentObjectUrl)
      }
      
      this.currentObjectUrl = objectUrl
    }
  }
  
  hidePreview() {
    if (this.hasPreviewContainerTarget) {
      this.previewContainerTarget.classList.add('hidden')
    }
    
    if (this.currentObjectUrl) {
      URL.revokeObjectURL(this.currentObjectUrl)
      this.currentObjectUrl = null
    }
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }
  
  disconnect() {
    // Cleanup when controller is removed
    if (this.currentObjectUrl) {
      URL.revokeObjectURL(this.currentObjectUrl)
    }
  }
}

