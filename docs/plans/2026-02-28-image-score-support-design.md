# Image Score Support Design

## Goal

Support JPG and PNG image files alongside PDFs as single-page score documents in Feuillet. Images appear in the same library grid, support annotations, and can be exported with annotations flattened.

## Approach

Add a `documentType` column to the `Documents` table (schema v5) to distinguish PDFs from images. Branch on this type throughout the rendering and import pipelines.

## Database

- Add `TextColumn documentType` to `Documents`, defaulting to `'pdf'`
- Schema version 5; migration sets `'pdf'` for all existing rows
- Values: `'pdf'`, `'image'`
- Add helper getters (`isPdf`, `isImage`) via extension or constants class

## Renames (Pdf* to Document*)

| Old | New | File rename |
|-----|-----|-------------|
| `PdfService` | `DocumentService` | `pdf_service.dart` → `document_service.dart` |
| `PdfCard` | `DocumentCard` | `pdf_card.dart` → `document_card.dart` |
| `PdfViewerScreen` | `DocumentViewerScreen` | `pdf_viewer_screen.dart` → `document_viewer_screen.dart` |
| `PdfImportResult` | `DocumentImportResult` | (in DocumentService) |
| `PdfExportService` | `DocumentExportService` | `pdf_export_service.dart` → `document_export_service.dart` |
| `FileAccessService.listPdfFiles()` | `listDocumentFiles()` | same file |
| SAF `listPdfFiles` | `listDocumentFiles` | `SafMethodChannel.kt` |

**Kept as-is:**
- `PdfPageCacheService` — genuinely PDF-specific, images bypass it
- `FileAccessService.openPdfDocument()` — PDF-specific method

## Import Pipeline

- File picker accepts `['pdf', 'jpg', 'jpeg', 'png']`
- Drag-and-drop validation accepts the same extensions
- Determine `documentType` from file extension on import
- Images: `pageCount = 1`, skip `pdfx` document opening
- PDFs: unchanged behavior
- `FileWatcherService`: watch for `.pdf`, `.jpg`, `.jpeg`, `.png`
- SAF Kotlin `listPdfFiles` → `listDocumentFiles`, filter extended to image extensions
- SAF `writeFile`: use dynamic MIME type based on extension

## Viewer

- `DocumentViewerScreen` branches on `document.documentType`:
  - **PDF:** Current pipeline (PdfDocument, page navigation, PdfPageCacheService)
  - **Image:** `Image.file` (native) or `Image.memory` (web), zoom/pan via existing `ZoomPanGestureMixin`, no page navigation
- Annotation layers work identically (DrawingCanvas is document-type agnostic, draws on page 1)
- Page indicator and navigation hidden for image documents

## Library Display

- `DocumentCard`: image icon (`Icons.image`) for image documents, `Icons.picture_as_pdf` for PDFs
- Page count text hidden or shows "Image" for image documents
- Thumbnails: load and resize image file directly (no PDF rendering needed)

## Export

- Image documents with annotations: render image + annotation strokes into a flattened PNG/JPG via `Canvas` + `ui.Image`
- PDF documents: unchanged export behavior
- Share uses appropriate MIME type based on document type

## Testing

- Update existing tests referencing PDF-specific names
- Add tests for image import (validation, pageCount, documentType)
- Add tests for image thumbnail generation
- Add tests for image viewer rendering path
