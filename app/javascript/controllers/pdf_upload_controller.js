import { Controller } from "@hotwired/stimulus"

// PDF upload with thumbnail preview and auto-upload
export default class extends Controller {
  static targets = ["frontInput", "backInput", "frontPreview", "backPreview", "frontDropZone", "backDropZone", "form", "submitButton"]
  
  connect() {
    console.log("PDF upload controller connected")
    // Load PDF.js from CDN
    this.loadPdfJs()
    this.submitTimeout = null
  }
  
  loadPdfJs() {
    if (window.pdfjsLib) {
      this.pdfJsReady = true
      return
    }
    
    // Load PDF.js from CDN
    const script = document.createElement('script')
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js'
    script.onload = () => {
      window.pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js'
      this.pdfJsReady = true
      console.log("PDF.js loaded successfully")
    }
    document.head.appendChild(script)
  }
  
  async handleFrontChange(event) {
    const file = event.target.files[0]
    if (file) {
      console.log('Front file selected:', file.name)
      await this.showPreview(file, this.frontPreviewTarget, this.frontDropZoneTarget, 'Front')
      console.log('Front preview complete, scheduling auto-submit')
      this.checkAndAutoSubmit()
    }
  }
  
  async handleBackChange(event) {
    const file = event.target.files[0]
    if (file) {
      console.log('Back file selected:', file.name)
      await this.showPreview(file, this.backPreviewTarget, this.backDropZoneTarget, 'Back')
      console.log('Back preview complete, scheduling auto-submit')
      this.checkAndAutoSubmit()
    }
  }
  
  async showPreview(file, previewTarget, dropZoneTarget, side) {
    // Show loading state
    dropZoneTarget.classList.add('hidden')
    previewTarget.classList.remove('hidden')
    previewTarget.innerHTML = `
      <div class="flex flex-col items-center justify-center h-full">
        <svg class="animate-spin h-12 w-12 text-gray-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="mt-2 text-sm text-gray-600">Generating preview...</p>
      </div>
    `
    
    // Wait for PDF.js to load
    let attempts = 0
    while (!this.pdfJsReady && attempts < 50) {
      await new Promise(resolve => setTimeout(resolve, 100))
      attempts++
    }
    
    if (!this.pdfJsReady) {
      previewTarget.innerHTML = `
        <div class="p-4 text-center">
          <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
          <p class="mt-2 text-sm font-medium text-gray-900">${file.name}</p>
          <p class="text-xs text-gray-500">${(file.size / 1024 / 1024).toFixed(2)} MB</p>
        </div>
      `
      return
    }
    
    try {
      console.log('Starting PDF preview rendering for:', file.name)
      
      // Create a URL for the file
      const fileUrl = URL.createObjectURL(file)
      
      // Load the PDF
      console.log('Loading PDF document...')
      const pdf = await window.pdfjsLib.getDocument(fileUrl).promise
      console.log('PDF loaded, getting first page...')
      const page = await pdf.getPage(1)
      
      // Calculate scale to fit in preview area
      const viewport = page.getViewport({ scale: 1 })
      const scale = Math.min(300 / viewport.width, 400 / viewport.height)
      const scaledViewport = page.getViewport({ scale })
      
      // Create canvas
      const canvas = document.createElement('canvas')
      canvas.width = scaledViewport.width
      canvas.height = scaledViewport.height
      canvas.className = 'mx-auto rounded shadow-sm'
      
      console.log('Rendering PDF to canvas...')
      const context = canvas.getContext('2d')
      await page.render({
        canvasContext: context,
        viewport: scaledViewport
      }).promise
      
      console.log('PDF rendered successfully!')
      
      // Update preview with thumbnail and info
      previewTarget.innerHTML = `
        <div class="relative group h-full flex flex-col">
          <div class="flex-1 flex items-center justify-center bg-gray-50 rounded-lg overflow-hidden">
            ${canvas.outerHTML}
          </div>
          <div class="mt-3 text-center">
            <p class="text-sm font-medium text-gray-900 truncate">${file.name}</p>
            <p class="text-xs text-gray-500">${(file.size / 1024 / 1024).toFixed(2)} MB</p>
          </div>
          <button type="button" 
                  data-action="click->pdf-upload#clear${side}" 
                  class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity bg-red-600 hover:bg-red-700 text-white rounded-full p-1.5">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      `
      
      // Clean up
      URL.revokeObjectURL(fileUrl)
    } catch (error) {
      console.error('Error rendering PDF:', error)
      previewTarget.innerHTML = `
        <div class="p-4 text-center">
          <svg class="mx-auto h-16 w-16 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <p class="mt-2 text-sm font-medium text-red-900">Error loading PDF</p>
          <p class="text-xs text-gray-500">${file.name}</p>
          <p class="text-xs text-gray-500 mt-1">${error.message}</p>
        </div>
      `
    }
  }
  
  clearFront(event) {
    event.preventDefault()
    this.frontInputTarget.value = ''
    this.frontPreviewTarget.classList.add('hidden')
    this.frontPreviewTarget.innerHTML = ''
    this.frontDropZoneTarget.classList.remove('hidden')
  }
  
  clearBack(event) {
    event.preventDefault()
    this.backInputTarget.value = ''
    this.backPreviewTarget.classList.add('hidden')
    this.backPreviewTarget.innerHTML = ''
    this.backDropZoneTarget.classList.remove('hidden')
  }
  
  checkAndAutoSubmit() {
    // Only auto-submit if front file is selected (back is optional)
    if (this.frontInputTarget.files.length > 0) {
      // Clear any existing timeout to avoid multiple submits
      if (this.submitTimeout) {
        clearTimeout(this.submitTimeout)
      }
      
      // Wait longer to allow user to see the preview and possibly select a second file
      this.submitTimeout = setTimeout(() => {
        this.uploadFiles()
      }, 1500) // 1.5 seconds to see preview
    }
  }
  
  async uploadFiles() {
    console.log('Starting silent upload...')
    
    // Show uploading state on button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Uploading...
      `
    }
    
    try {
      // Create FormData from the form
      const formData = new FormData(this.formTarget)
      
      // Get the form action URL and method
      const url = this.formTarget.action
      const method = this.formTarget.method || 'POST'
      
      console.log('Uploading to:', url)
      
      // Upload via fetch (AJAX)
      const response = await fetch(url, {
        method: method,
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        console.log('Upload successful!')
        
        // Show success message
        this.showSuccessMessage()
        
        // Reset button
        if (this.hasSubmitButtonTarget) {
          this.submitButtonTarget.disabled = false
          this.submitButtonTarget.innerHTML = 'Upload Files'
        }
        
        // Clear file inputs but keep previews
        // (so user can upload different files if needed)
      } else {
        console.error('Upload failed:', response.statusText)
        this.showErrorMessage('Upload failed. Please try again.')
        
        // Reset button
        if (this.hasSubmitButtonTarget) {
          this.submitButtonTarget.disabled = false
          this.submitButtonTarget.innerHTML = 'Upload Files'
        }
      }
    } catch (error) {
      console.error('Upload error:', error)
      this.showErrorMessage('Upload error: ' + error.message)
      
      // Reset button
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.innerHTML = 'Upload Files'
      }
    }
  }
  
  showSuccessMessage() {
    // Create success notification
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 z-50 bg-green-600 text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-2'
    notification.innerHTML = `
      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
      </svg>
      <span>Files uploaded successfully!</span>
    `
    document.body.appendChild(notification)
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
  
  showErrorMessage(message) {
    // Create error notification
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 z-50 bg-red-600 text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-2'
    notification.innerHTML = `
      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
      </svg>
      <span>${message}</span>
    `
    document.body.appendChild(notification)
    
    // Remove after 5 seconds
    setTimeout(() => {
      notification.remove()
    }, 5000)
  }
}

