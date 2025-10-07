# PDF Upload with Thumbnail Preview

## Overview
Enhanced PDF upload experience for campaign creative files with instant thumbnail previews and automatic form submission.

## Features

### 1. Instant Thumbnail Preview
- PDFs are rendered as thumbnails immediately after file selection
- Uses PDF.js library loaded from CDN
- Shows loading state while generating preview
- Displays file name and size below thumbnail

### 2. Automatic Upload
- Form automatically submits after file selection
- 800ms debounce to allow selecting both front and back files
- No need to click the "Upload Files" button
- Shows "Uploading..." state during submission

### 3. File Management
- Clear button appears on hover to remove selected file
- Front PDF is required, back PDF is optional
- Supports drag-and-drop (native browser functionality)
- Validates PDF format on upload

## Technical Implementation

### Stimulus Controller
Location: `app/javascript/controllers/pdf_upload_controller.js`

**Key Methods:**
- `connect()` - Initializes controller and loads PDF.js library
- `handleFrontChange()` - Handles front PDF selection
- `handleBackChange()` - Handles back PDF selection
- `showPreview()` - Renders PDF thumbnail using canvas
- `checkAndAutoSubmit()` - Auto-submits form with debounce
- `clearFront()`/`clearBack()` - Remove selected files

### View Template
Location: `app/views/campaigns/tabs/_design.html.erb`

**Data Attributes:**
- `data-controller="pdf-upload"` - Activates Stimulus controller
- `data-pdf-upload-target="frontInput"` - Front file input
- `data-pdf-upload-target="backInput"` - Back file input
- `data-pdf-upload-target="frontPreview"` - Front preview area
- `data-pdf-upload-target="backPreview"` - Back preview area
- `data-pdf-upload-target="frontDropZone"` - Front drop zone
- `data-pdf-upload-target="backDropZone"` - Back drop zone
- `data-pdf-upload-target="form"` - Form element
- `data-pdf-upload-target="submitButton"` - Submit button

## User Experience Flow

1. **Single File Upload:**
   - User clicks "Upload a file" or drags PDF onto drop zone
   - Loading spinner appears ("Generating preview...")
   - PDF thumbnail renders immediately (first page)
   - After 1.5 seconds, silent AJAX upload begins
   - Thumbnail stays visible during upload
   - Success notification appears (no page reload!)
   - Files are uploaded and saved

2. **Two File Upload:**
   - User selects front PDF → Thumbnail appears
   - Within 1.5 seconds, user selects back PDF → Thumbnail appears
   - AJAX upload begins (debounced)
   - Both thumbnails stay visible during upload
   - Success notification appears
   - Both files uploaded without page refresh

3. **Clear and Re-upload:**
   - User hovers over thumbnail
   - Clicks X button to clear selection
   - Drop zone reappears
   - User can select a different file
   - Upload happens again via AJAX

## Dependencies

- **PDF.js** - Loaded from CDN (v3.11.174)
  - Main library: `pdf.min.js`
  - Worker: `pdf.worker.min.js`
  - No npm installation required

- **Stimulus** - Already part of Rails app
- **Tailwind CSS** - For styling

## Browser Compatibility

- Modern browsers with File API support
- Canvas API for PDF rendering
- ES6+ async/await support

## Future Enhancements

- [ ] Drag and drop file upload
- [ ] Multiple page preview
- [ ] Client-side PDF validation (dimensions, DPI)
- [ ] Progress indicator for large files
- [ ] Preview zoom/pan functionality

