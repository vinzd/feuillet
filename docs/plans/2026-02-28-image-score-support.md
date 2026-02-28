# Image Score Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Support JPG/PNG image files as single-page score documents alongside PDFs, with full annotation and export support.

**Architecture:** Add a `documentType` column to the Documents table (schema v5). Branch on this type in import, rendering, and export pipelines. Rename `Pdf*` classes/files to `Document*` to reflect the broadened scope. Images bypass `PdfPageCacheService` and render directly via Flutter's `Image` widget.

**Tech Stack:** Flutter, Drift (SQLite), pdfx, dart:ui (for image export with annotations)

---

### Task 1: Add `documentType` column to database schema

**Files:**
- Modify: `lib/models/database.dart:8-19` (Documents table)
- Modify: `lib/models/database.dart:110` (schemaVersion)
- Modify: `lib/models/database.dart:118-131` (migration)

**Step 1: Add documentType column to Documents table**

In `lib/models/database.dart`, add a `documentType` text column after `pageCount`:

```dart
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text()();
  BlobColumn get pdfBytes =>
      blob().nullable()(); // For web platform - stores PDF bytes
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpened => dateTime().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  IntColumn get fileSize => integer()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  TextColumn get documentType =>
      text().withDefault(const Constant('pdf'))(); // 'pdf' or 'image'
}
```

**Step 2: Bump schema version and add migration**

Change `schemaVersion` from 4 to 5. Add migration block:

```dart
int get schemaVersion => 5;
```

In the `onUpgrade` method, add:

```dart
if (from < 5) {
  // Add documentType column for image support
  await m.addColumn(documents, documents.documentType);
}
```

**Step 3: Add DocumentType helper**

Add above the `Documents` class in `database.dart`:

```dart
/// Document types supported by the app
class DocumentTypes {
  static const String pdf = 'pdf';
  static const String image = 'image';

  /// Supported file extensions by type
  static const List<String> pdfExtensions = ['pdf'];
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> allExtensions = [...pdfExtensions, ...imageExtensions];

  /// Determine document type from file extension
  static String fromExtension(String ext) {
    final lower = ext.toLowerCase().replaceAll('.', '');
    if (imageExtensions.contains(lower)) return image;
    return pdf;
  }

  /// Determine document type from file path
  static String fromPath(String filePath) {
    final ext = filePath.split('.').last;
    return fromExtension(ext);
  }
}

/// Extension on Document for type checking
extension DocumentTypeHelpers on Document {
  bool get isPdf => documentType == DocumentTypes.pdf;
  bool get isImage => documentType == DocumentTypes.image;
}
```

**Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 5: Run tests to check nothing broke**

Run: `flutter test`

**Step 6: Commit**

```bash
git add lib/models/database.dart lib/models/database.g.dart
git commit -m "feat: add documentType column to Documents table (schema v5)"
```

---

### Task 2: Rename PdfService → DocumentService

**Files:**
- Rename: `lib/services/pdf_service.dart` → `lib/services/document_service.dart`
- Modify: all files that import `pdf_service.dart`

Affected importers (from grep):
- `lib/widgets/pdf_card.dart`
- `lib/services/file_watcher_service.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/library_screen.dart`
- `lib/main.dart`
- `test/services/pdf_service_test.dart`

**Step 1: Rename file and class**

Rename `lib/services/pdf_service.dart` → `lib/services/document_service.dart`.

Inside the file:
- `PdfService` → `DocumentService` (class name, all references)
- `PdfImportResult` → `DocumentImportResult`
- `PdfImportBatchResult` → `DocumentImportBatchResult`
- Update all debug prints from `'PdfService:'` to `'DocumentService:'`
- Update doc comments

**Step 2: Update all import statements**

In every file that imports `pdf_service.dart`, change:
```dart
import '../services/pdf_service.dart';
// to
import '../services/document_service.dart';
```

And update all references from `PdfService.instance` to `DocumentService.instance`, `PdfImportResult` to `DocumentImportResult`, etc.

**Step 3: Rename test file**

Rename `test/services/pdf_service_test.dart` → `test/services/document_service_test.dart`. Update class references inside.

**Step 4: Run tests**

Run: `flutter test`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename PdfService to DocumentService"
```

---

### Task 3: Rename PdfCard → DocumentCard

**Files:**
- Rename: `lib/widgets/pdf_card.dart` → `lib/widgets/document_card.dart`
- Modify: importers (`lib/screens/library_screen.dart`)
- Rename: `test/widgets/pdf_card_test.dart` → `test/widgets/document_card_test.dart`

**Step 1: Rename file and class**

Rename `lib/widgets/pdf_card.dart` → `lib/widgets/document_card.dart`.

Inside:
- `PdfCard` → `DocumentCard`
- `_PdfCardState` → `_DocumentCardState`

**Step 2: Update imports in library_screen.dart**

Change import path and all `PdfCard` references to `DocumentCard`.

**Step 3: Rename and update test file**

**Step 4: Run tests**

Run: `flutter test`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename PdfCard to DocumentCard"
```

---

### Task 4: Rename PdfViewerScreen → DocumentViewerScreen

**Files:**
- Rename: `lib/screens/pdf_viewer_screen.dart` → `lib/screens/document_viewer_screen.dart`
- Modify: importers (`lib/screens/wrappers/pdf_viewer_wrapper.dart`)
- Rename: `test/screens/pdf_viewer_prerender_test.dart` → `test/screens/document_viewer_prerender_test.dart`

**Step 1: Rename file and class**

Rename `lib/screens/pdf_viewer_screen.dart` → `lib/screens/document_viewer_screen.dart`.

Inside:
- `PdfViewerScreen` → `DocumentViewerScreen`
- `_PdfViewerScreenState` → `_DocumentViewerScreenState`

**Step 2: Update imports in wrapper and any navigation references**

Update `lib/screens/wrappers/pdf_viewer_wrapper.dart` import and class references.

**Step 3: Rename and update test file**

**Step 4: Run tests**

Run: `flutter test`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename PdfViewerScreen to DocumentViewerScreen"
```

---

### Task 5: Rename PdfExportService → DocumentExportService

**Files:**
- Rename: `lib/services/pdf_export_service.dart` → `lib/services/document_export_service.dart`
- Modify: `lib/widgets/export_pdf_dialog.dart`, `lib/screens/library_screen.dart`
- Rename: `test/services/pdf_export_service_test.dart` → `test/services/document_export_service_test.dart`

**Step 1: Rename file and class**

- `PdfExportService` → `DocumentExportService`
- Update all debug prints and doc comments

**Step 2: Update importers**

**Step 3: Rename and update test file**

**Step 4: Run tests**

Run: `flutter test`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename PdfExportService to DocumentExportService"
```

---

### Task 6: Rename FileAccessService.listPdfFiles → listDocumentFiles

**Files:**
- Modify: `lib/services/file_access_service.dart:62-112` (method + helpers)
- Modify: `lib/services/pdf_service.dart` (now `document_service.dart`)
- Modify: `android/app/src/main/kotlin/com/feuillet/app/SafMethodChannel.kt`
- Modify: `test/services/file_access_service_test.dart`

**Step 1: Rename Dart method and update references**

In `file_access_service.dart`:
- `listPdfFiles` → `listDocumentFiles`
- `_listPdfFilesSaf` → `_listDocumentFilesSaf`
- `_listPdfFilesLocal` → `_listDocumentFilesLocal`
- `PdfFileInfo` → `DocumentFileInfo`
- Update the SAF channel call from `'listPdfFiles'` to `'listDocumentFiles'`

In `document_service.dart` (was `pdf_service.dart`):
- Update the call from `listPdfFiles` to `listDocumentFiles`

**Step 2: Rename Kotlin SAF method**

In `SafMethodChannel.kt`:
- `"listPdfFiles"` → `"listDocumentFiles"` (method dispatch, line ~24)
- `listPdfFiles()` → `listDocumentFiles()` (function name)
- `collectPdfFiles()` → `collectDocumentFiles()` (helper)

**Step 3: Update test references**

**Step 4: Run tests**

Run: `flutter test`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename listPdfFiles to listDocumentFiles"
```

---

### Task 7: Extend file filtering to accept image extensions

**Files:**
- Modify: `lib/services/file_access_service.dart:99` (local file filter)
- Modify: `lib/services/file_watcher_service.dart:138` (watcher filter)
- Modify: `android/app/src/main/kotlin/com/feuillet/app/SafMethodChannel.kt:96` (SAF filter)

**Step 1: Update local file listing filter**

In `file_access_service.dart`, `_listDocumentFilesLocal()`, change line 99:

```dart
// Before:
if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {

// After:
final ext = entity.path.split('.').last.toLowerCase();
if (entity is File && DocumentTypes.allExtensions.contains(ext)) {
```

Add import for `DocumentTypes` from `database.dart`.

**Step 2: Update file watcher filter**

In `file_watcher_service.dart`, line 138, change:

```dart
// Before:
if (p.extension(event.path).toLowerCase() == '.pdf') {

// After:
final ext = p.extension(event.path).toLowerCase().replaceAll('.', '');
if (DocumentTypes.allExtensions.contains(ext)) {
```

Add import for `DocumentTypes` from `database.dart`.

**Step 3: Update SAF Kotlin filter**

In `SafMethodChannel.kt`, `collectDocumentFiles()`, change:

```kotlin
// Before:
else if (file.isFile && file.name?.lowercase()?.endsWith(".pdf") == true)

// After:
else if (file.isFile && isDocumentFile(file.name))
```

Add helper:

```kotlin
private fun isDocumentFile(name: String?): Boolean {
    val lower = name?.lowercase() ?: return false
    return lower.endsWith(".pdf") || lower.endsWith(".jpg") ||
           lower.endsWith(".jpeg") || lower.endsWith(".png")
}
```

Also update `writeFile()` MIME type (line ~179):

```kotlin
// Before:
val newFile = parentDoc.createFile("application/pdf", fileName)

// After:
val mimeType = when {
    fileName.lowercase().endsWith(".jpg") || fileName.lowercase().endsWith(".jpeg") -> "image/jpeg"
    fileName.lowercase().endsWith(".png") -> "image/png"
    else -> "application/pdf"
}
val newFile = parentDoc.createFile(mimeType, fileName)
```

**Step 4: Write test for image file filtering**

In `test/services/file_access_service_test.dart`, add test:

```dart
test('listDocumentFiles includes image files', () async {
  // Create test directory with PDF and image files
  final dir = await Directory.systemTemp.createTemp('test_docs_');
  await File('${dir.path}/score.pdf').writeAsBytes([0x25, 0x50, 0x44, 0x46]);
  await File('${dir.path}/photo.jpg').writeAsBytes([0xFF, 0xD8, 0xFF]);
  await File('${dir.path}/sheet.png').writeAsBytes([0x89, 0x50, 0x4E, 0x47]);
  await File('${dir.path}/notes.txt').writeAsString('hello');

  final files = await FileAccessService.instance.listDocumentFiles(dir.path);
  final names = files.map((f) => f.name).toSet();

  expect(names, contains('score.pdf'));
  expect(names, contains('photo.jpg'));
  expect(names, contains('sheet.png'));
  expect(names, isNot(contains('notes.txt')));

  await dir.delete(recursive: true);
});
```

**Step 5: Run tests**

Run: `flutter test`

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: extend file filters to accept jpg/jpeg/png alongside pdf"
```

---

### Task 8: Update import pipeline for image support

**Files:**
- Modify: `lib/services/document_service.dart` (was pdf_service.dart)

**Step 1: Update file picker extensions**

In `importDocuments()` (was `importPdfs`), line ~204:

```dart
allowedExtensions: DocumentTypes.allExtensions,
```

**Step 2: Update dropped file validation**

In `_importDroppedFile()`, line ~269:

```dart
// Before:
if (!fileName.toLowerCase().endsWith('.pdf')) {
  return DocumentImportResult(
    fileName: fileName,
    success: false,
    error: 'Not a PDF file',
  );
}

// After:
final ext = fileName.split('.').last.toLowerCase();
if (!DocumentTypes.allExtensions.contains(ext)) {
  return DocumentImportResult(
    fileName: fileName,
    success: false,
    error: 'Unsupported file type. Supported: PDF, JPG, PNG',
  );
}
```

**Step 3: Update addDocumentToLibrary (was addPdfToLibrary)**

Rename method to `addDocumentToLibrary`. Determine document type and page count based on type:

```dart
Future<String?> addDocumentToLibrary(String filePath) async {
  try {
    final fileAccess = FileAccessService.instance;
    if (!await fileAccess.fileExists(filePath)) {
      debugPrint('DocumentService: File does not exist: $filePath');
      return null;
    }

    final metadata = await fileAccess.getFileMetadata(filePath);
    final fileName = isSafUri(filePath)
        ? p.basenameWithoutExtension(Uri.parse(filePath).pathSegments.last)
        : p.basenameWithoutExtension(filePath);
    final docType = DocumentTypes.fromPath(filePath);
    final pageCount = docType == DocumentTypes.pdf
        ? await _getPdfPageCount(filePath)
        : 1; // Images are always 1 page

    final documentId = await _database.insertDocument(
      DocumentsCompanion(
        name: drift.Value(fileName),
        filePath: drift.Value(filePath),
        lastModified: drift.Value(metadata.lastModified),
        fileSize: drift.Value(metadata.size),
        pageCount: drift.Value(pageCount),
        documentType: drift.Value(docType),
      ),
    );

    // Create default settings
    await _database.insertOrUpdateDocumentSettings(
      DocumentSettingsCompanion(
        documentId: drift.Value(documentId),
        zoomLevel: const drift.Value(1.0),
        brightness: const drift.Value(0.0),
        contrast: const drift.Value(1.0),
        currentPage: const drift.Value(0),
      ),
    );

    debugPrint(
      'DocumentService: Added $docType to library: $fileName (ID: $documentId)',
    );
    return filePath;
  } catch (e, stackTrace) {
    debugPrint('DocumentService: Error adding document to library: $e');
    debugPrint(stackTrace.toString());
    return null;
  }
}
```

**Step 4: Update _addFromBytes for web platform**

In `_addDocumentFromBytes` (was `_addPdfFromBytes`), determine type from filename:

```dart
final docType = DocumentTypes.fromPath(fileName);
final pageCount = docType == DocumentTypes.pdf
    ? await _getPdfPageCountFromBytes(bytes)
    : 1;
```

Add `documentType: drift.Value(docType)` to the `DocumentsCompanion`.

**Step 5: Rename remaining PDF-specific methods**

- `importPdfs` → `importDocuments`
- `importPdfsFromDroppedFiles` → `importDocumentsFromDroppedFiles`
- `addPdfToLibrary` → `addDocumentToLibrary`
- `deletePdf` → `deleteDocument`
- `_addPdfFromBytes` → `_addDocumentFromBytes`
- `_copyToPdfDirectory` → `_copyToDocumentDirectory`

Update all callers (library_screen.dart, main.dart, settings_screen.dart, file_watcher_service.dart).

**Step 6: Run tests**

Run: `flutter test`

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: update import pipeline to accept image files"
```

---

### Task 9: Update thumbnail generation for images

**Files:**
- Modify: `lib/services/document_service.dart` (generateThumbnail method, line ~576)

**Step 1: Add image thumbnail generation**

Modify `generateThumbnail()` to branch on document type:

```dart
Future<Uint8List?> generateThumbnail(Document document) async {
  try {
    // Check cache first (native only)
    File? thumbFile;
    if (!kIsWeb) {
      final thumbPath = await _getThumbnailPath(document.id);
      thumbFile = File(thumbPath);
      if (await thumbFile.exists()) {
        return await thumbFile.readAsBytes();
      }
    }

    Uint8List? thumbnailBytes;

    if (document.isImage) {
      thumbnailBytes = await _generateImageThumbnail(document);
    } else {
      thumbnailBytes = await _generatePdfThumbnail(document);
    }

    // Cache on native platforms
    if (!kIsWeb && thumbFile != null && thumbnailBytes != null) {
      await thumbFile.writeAsBytes(thumbnailBytes);
    }

    return thumbnailBytes;
  } catch (e) {
    debugPrint('DocumentService: Error generating thumbnail: $e');
    return null;
  }
}

/// Generate thumbnail for an image document
Future<Uint8List?> _generateImageThumbnail(Document document) async {
  if (document.pdfBytes != null) {
    // Web: use stored bytes directly
    return Uint8List.fromList(document.pdfBytes!);
  }
  // Native: read file bytes (no rendering needed, the card widget will resize)
  return await FileAccessService.instance.readFileBytes(document.filePath);
}

/// Generate thumbnail for a PDF document (existing logic)
Future<Uint8List?> _generatePdfThumbnail(Document document) async {
  final pdfDoc = await FileAccessService.instance.openPdfDocument(
    document.filePath,
    pdfBytes: document.pdfBytes != null
        ? Uint8List.fromList(document.pdfBytes!)
        : null,
  );

  final page = await pdfDoc.getPage(1);
  const double thumbnailWidth = 300;
  final scale = thumbnailWidth / page.width;
  final pageImage = await page.render(
    width: thumbnailWidth,
    height: page.height * scale,
    format: PdfPageImageFormat.png,
    backgroundColor: '#FFFFFF',
  );

  await page.close();
  await pdfDoc.close();

  if (pageImage == null) {
    debugPrint('DocumentService: Failed to render page for thumbnail');
    return null;
  }

  return pageImage.bytes;
}
```

**Step 2: Run tests**

Run: `flutter test`

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add image thumbnail generation"
```

---

### Task 10: Update DocumentCard for image documents

**Files:**
- Modify: `lib/widgets/document_card.dart` (was pdf_card.dart)

**Step 1: Update fallback icon based on document type**

Around line ~93, change the fallback icon:

```dart
// Before:
Icon(Icons.picture_as_pdf, ...)

// After:
Icon(
  widget.document.isImage ? Icons.image : Icons.picture_as_pdf,
  ...
)
```

**Step 2: Update page count display**

Around line ~157, change:

```dart
// Before:
Text('${widget.document.pageCount} pages', ...)

// After:
Text(
  widget.document.isImage
      ? 'Image'
      : '${widget.document.pageCount} pages',
  ...
)
```

Add import for `DocumentTypeHelpers` extension (from `database.dart`).

**Step 3: Run tests**

Run: `flutter test`

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: update DocumentCard to show image-specific icon and label"
```

---

### Task 11: Update DocumentViewerScreen for image display

**Files:**
- Modify: `lib/screens/document_viewer_screen.dart` (was pdf_viewer_screen.dart)

**Step 1: Add image display branch in the viewer**

In `_initializeDocument` (was `_initializePdf`), branch on document type:

```dart
if (freshDocument.isImage) {
  // Images don't need PdfDocument - load bytes for display
  if (freshDocument.pdfBytes != null) {
    _imageBytes = Uint8List.fromList(freshDocument.pdfBytes!);
  } else {
    _imageBytes = await FileAccessService.instance.readFileBytes(
      freshDocument.filePath,
    );
  }
  if (mounted) setState(() {});
} else {
  // Existing PDF loading pipeline
  final pdfDoc = await FileAccessService.instance.openPdfDocument(
    freshDocument.filePath,
    pdfBytes: freshDocument.pdfBytes != null
        ? Uint8List.fromList(freshDocument.pdfBytes!)
        : null,
  );
  // ... rest of existing PDF init
}
```

Add field: `Uint8List? _imageBytes;`

**Step 2: Add image content widget**

Create a method for rendering image content:

```dart
Widget _buildImageContent() {
  if (_imageBytes == null) {
    return const Center(child: CircularProgressIndicator());
  }
  return Image.memory(
    _imageBytes!,
    fit: BoxFit.contain,
  );
}
```

**Step 3: Branch in build method**

Where the PDF page view is built, add a branch:

```dart
if (widget.document.isImage) {
  // Use image content widget (still wrapped in zoom/pan and drawing canvas)
  child = _buildImageContent();
} else {
  // Existing PDF page view
  child = _buildPdfContent();
}
```

**Step 4: Hide page navigation for images**

In the bottom controls or page indicator, conditionally hide:

```dart
if (!widget.document.isImage) ...[
  // page indicator, page navigation arrows
]
```

**Step 5: Ensure annotation overlay works for images**

The `DrawingCanvas` overlay should work as-is since it operates on page 1 and is positioned over the content area. Verify that the annotation layer loading (which already works for page 1) functions correctly with image documents.

**Step 6: Run tests**

Run: `flutter test`

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: add image display support in DocumentViewerScreen"
```

---

### Task 12: Update export for image documents

**Files:**
- Modify: `lib/services/document_export_service.dart` (was pdf_export_service.dart)
- Modify: `lib/widgets/export_pdf_dialog.dart`

**Step 1: Add image export with flattened annotations**

Add a new method to `DocumentExportService`:

```dart
/// Export an image with annotations burned in as a flattened PNG
Future<Uint8List> exportImageWithAnnotations({
  required Document document,
  required Uint8List imageBytes,
  required List<int> selectedLayerIds,
  required Size imageSize,
}) async {
  // Load the original image
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final originalImage = frame.image;

  // Create a canvas at the image size
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Draw the original image
  canvas.drawImage(originalImage, Offset.zero, Paint());

  // Draw annotations on top
  final annotations = await _annotationService.getAnnotationsForPage(
    document.id,
    1,
    selectedLayerIds,
  );
  _drawAnnotationsOnCanvas(canvas, annotations, originalImage.width.toDouble(),
      originalImage.height.toDouble());

  // Encode as PNG
  final picture = recorder.endRecording();
  final img = await picture.toImage(originalImage.width, originalImage.height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  originalImage.dispose();
  img.dispose();

  return byteData!.buffer.asUint8List();
}
```

**Step 2: Update export dialog to handle images**

In `export_pdf_dialog.dart`, branch on document type to call the appropriate export method and use the correct file extension/MIME type for sharing.

**Step 3: Run tests**

Run: `flutter test`

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add image export with flattened annotations"
```

---

### Task 13: Update CLAUDE.md and docs

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update CLAUDE.md references**

Update all references to renamed classes and files:
- `PdfService` → `DocumentService`
- `PdfCard` → `DocumentCard`
- `PdfViewerScreen` → `DocumentViewerScreen`
- `PdfExportService` → `DocumentExportService`
- `listPdfFiles` → `listDocumentFiles`
- Add note about image support and `DocumentTypes` class
- Update schema version reference to 5
- Add `documentType` to the Documents table description

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for image support and renames"
```

---

### Task 14: Final integration test

**Step 1: Run full test suite**

Run: `flutter test`

**Step 2: Run analyzer**

Run: `flutter analyze`

**Step 3: Run formatter**

Run: `dart format lib/ test/`

**Step 4: Manual smoke test on web**

Run: `make run-web`

Verify:
- Import a PDF - works as before
- Import a JPG/PNG - appears in library with image icon
- Open an image - displays correctly with zoom/pan
- Annotations on image - can draw and save
- Export image with annotations - produces flattened image

**Step 5: Final commit if any formatting/analysis fixes**

```bash
git add -A
git commit -m "chore: fix formatting and analysis issues"
```
