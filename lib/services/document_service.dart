import 'dart:io';
import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:watcher/watcher.dart';
// cross_file is used for the XFile type from desktop_drop
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart' show XFile;
import '../models/database.dart';
import 'database_service.dart';
import 'file_access_service.dart';
import 'file_watcher_service.dart';

/// Result of importing a single document file
class DocumentImportResult {
  final String fileName;
  final bool success;
  final String? error;
  final String? filePath;

  const DocumentImportResult({
    required this.fileName,
    required this.success,
    this.error,
    this.filePath,
  });
}

/// Result of a batch document import operation
class DocumentImportBatchResult {
  final List<DocumentImportResult> results;

  const DocumentImportBatchResult(this.results);

  int get successCount => results.where((r) => r.success).length;
  int get failureCount => results.where((r) => !r.success).length;
  int get totalCount => results.length;
  bool get hasFailures => failureCount > 0;
  bool get allSucceeded => failureCount == 0;
  List<DocumentImportResult> get failures =>
      results.where((r) => !r.success).toList();
}

/// Service to manage PDF files and library operations
class DocumentService {
  DocumentService._() {
    _initialize();
  }

  static final DocumentService instance = DocumentService._();

  StreamSubscription? _pdfChangesSubscription;
  final _database = DatabaseService.instance.database;

  /// Initialize the service and set up file watchers
  void _initialize() {
    // Skip file watching on web (for development iteration only)
    if (kIsWeb) {
      debugPrint('DocumentService: Skipping file watcher on web platform');
      return;
    }

    // Register SAF polling callback for Android SAF directories
    FileWatcherService.instance.onSafPollCallback = () => scanAndSyncLibrary();

    // Listen to PDF directory changes from Syncthing
    _pdfChangesSubscription = FileWatcherService.instance.pdfChanges.listen(
      _handlePdfDirectoryChange,
      onError: (error) {
        debugPrint('DocumentService: Error in PDF watcher: $error');
      },
    );
  }

  /// Handle PDF directory changes detected by file watcher
  Future<void> _handlePdfDirectoryChange(WatchEvent event) async {
    debugPrint(
      'DocumentService: PDF directory changed: ${event.type} - ${event.path}',
    );

    switch (event.type) {
      case ChangeType.ADD:
        await _handleNewPdf(event.path);
        break;
      case ChangeType.REMOVE:
        await _handleRemovedPdf(event.path);
        break;
      case ChangeType.MODIFY:
        await _handleModifiedPdf(event.path);
        break;
    }
  }

  /// Handle a new PDF file added by Syncthing
  Future<void> _handleNewPdf(String filePath) async {
    try {
      // Check if this PDF is already in the database
      final existingDocs = await _database.getAllDocuments();
      final alreadyExists = existingDocs.any((doc) => doc.filePath == filePath);

      if (alreadyExists) {
        debugPrint('DocumentService: PDF already in database: $filePath');
        return;
      }

      // Add to database
      await addPdfToLibrary(filePath);
      debugPrint('DocumentService: Added new PDF from Syncthing: $filePath');
    } catch (e) {
      debugPrint('DocumentService: Error handling new PDF: $e');
    }
  }

  /// Find a document by file path
  Future<Document?> _findDocumentByPath(String filePath) async {
    final docs = await _database.getAllDocuments();
    for (final doc in docs) {
      if (doc.filePath == filePath) return doc;
    }
    return null;
  }

  /// Handle a PDF file removed by Syncthing
  Future<void> _handleRemovedPdf(String filePath) async {
    try {
      final doc = await _findDocumentByPath(filePath);
      if (doc != null) {
        await _database.deleteDocument(doc.id);
        debugPrint('DocumentService: Removed PDF from database: $filePath');
      }
    } catch (e) {
      debugPrint('DocumentService: Error handling removed PDF: $e');
    }
  }

  /// Handle a PDF file modified by Syncthing
  Future<void> _handleModifiedPdf(String filePath) async {
    try {
      final doc = await _findDocumentByPath(filePath);
      if (doc != null) {
        final metadata = await FileAccessService.instance.getFileMetadata(
          filePath,
        );

        await _database.updateDocument(
          doc.copyWith(
            lastModified: metadata.lastModified,
            fileSize: metadata.size,
          ),
        );
        debugPrint('DocumentService: Updated PDF metadata: $filePath');
      }
    } catch (e) {
      debugPrint('DocumentService: Error handling modified PDF: $e');
    }
  }

  /// Copy a file to the PDF directory with a unique name if needed
  Future<String> _copyToPdfDirectory(String sourcePath) async {
    final fileAccess = FileAccessService.instance;
    final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
    final fileName = p.basename(sourcePath);

    if (isSafUri(pdfDir)) {
      // SAF directory: read source bytes and write to SAF
      final bytes = await File(sourcePath).readAsBytes();
      return fileAccess.writeFileToDirectory(pdfDir, fileName, bytes);
    }

    final destPath = p.join(pdfDir, fileName);

    // Generate unique name if file already exists
    if (await fileAccess.fileExists(destPath)) {
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${nameWithoutExt}_$timestamp$ext';
      final uniquePath = p.join(pdfDir, uniqueName);
      await File(sourcePath).copy(uniquePath);
      return uniquePath;
    }

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Import one or more PDF files using file picker
  ///
  /// Returns a [DocumentImportBatchResult] with results for each file,
  /// or null if the user cancelled the file picker.
  ///
  /// Optional [onProgress] callback is called after each file is processed
  /// with (currentIndex, totalCount, currentFileName).
  Future<DocumentImportBatchResult?> importPdfs({
    void Function(int current, int total, String fileName)? onProgress,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: kIsWeb, // Load bytes on web
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final results = <DocumentImportResult>[];
      final total = result.files.length;

      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        onProgress?.call(i + 1, total, file.name);
        results.add(await _importSingleFile(file));
      }

      return DocumentImportBatchResult(results);
    } catch (e) {
      debugPrint('DocumentService: Error opening file picker: $e');
      return null;
    }
  }

  /// Import a single PDF file using file picker (convenience method)
  @Deprecated('Use importPdfs() instead for multi-file support')
  Future<String?> importPdf() async {
    final result = await importPdfs();
    if (result == null || result.results.isEmpty) {
      return null;
    }
    final first = result.results.first;
    return first.success ? first.filePath : null;
  }

  /// Import PDFs from dropped files (desktop_drop integration)
  ///
  /// For native platforms, uses file paths. For web, uses file bytes.
  /// Returns a [DocumentImportBatchResult] with results for each file.
  ///
  /// Optional [onProgress] callback is called after each file is processed
  /// with (currentIndex, totalCount, currentFileName).
  Future<DocumentImportBatchResult> importPdfsFromDroppedFiles(
    List<XFile> files, {
    void Function(int current, int total, String fileName)? onProgress,
  }) async {
    final results = <DocumentImportResult>[];
    final total = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = file.name;

      onProgress?.call(i + 1, total, fileName);
      results.add(await _importDroppedFile(file));
    }

    return DocumentImportBatchResult(results);
  }

  /// Import a single dropped file
  Future<DocumentImportResult> _importDroppedFile(XFile file) async {
    final fileName = file.name;

    if (!fileName.toLowerCase().endsWith('.pdf')) {
      return DocumentImportResult(
        fileName: fileName,
        success: false,
        error: 'Not a PDF file',
      );
    }

    if (kIsWeb) {
      return _importDroppedFileFromBytes(file);
    }
    return _importDroppedFileFromPath(file);
  }

  /// Import a dropped file using bytes (web platform)
  Future<DocumentImportResult> _importDroppedFileFromBytes(XFile file) async {
    final bytes = await file.readAsBytes();
    final path = await _addPdfFromBytes(file.name, bytes);
    return DocumentImportResult(
      fileName: file.name,
      success: path != null,
      filePath: path,
      error: path == null ? 'Failed to add PDF' : null,
    );
  }

  /// Import a dropped file using file path (native platforms)
  Future<DocumentImportResult> _importDroppedFileFromPath(XFile file) async {
    final filePath = file.path;
    if (filePath.isEmpty) {
      return DocumentImportResult(
        fileName: file.name,
        success: false,
        error: 'No file path available',
      );
    }

    final destPath = await _copyToPdfDirectory(filePath);
    final addedPath = await addPdfToLibrary(destPath);
    return DocumentImportResult(
      fileName: file.name,
      success: addedPath != null,
      filePath: addedPath,
      error: addedPath == null ? 'Failed to add PDF to library' : null,
    );
  }

  /// Import a single file from the file picker result
  Future<DocumentImportResult> _importSingleFile(PlatformFile file) async {
    try {
      if (kIsWeb) {
        return await _importFileFromBytes(file);
      }
      return await _importFileFromPath(file);
    } catch (e) {
      debugPrint('DocumentService: Error importing ${file.name}: $e');
      return DocumentImportResult(
        fileName: file.name,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Import a file using bytes (web platform)
  Future<DocumentImportResult> _importFileFromBytes(PlatformFile file) async {
    if (file.bytes == null) {
      return DocumentImportResult(
        fileName: file.name,
        success: false,
        error: 'No bytes available',
      );
    }
    final path = await _addPdfFromBytes(file.name, file.bytes!);
    return DocumentImportResult(
      fileName: file.name,
      success: path != null,
      filePath: path,
      error: path == null ? 'Failed to add PDF' : null,
    );
  }

  /// Import a file using file path (native platforms)
  Future<DocumentImportResult> _importFileFromPath(PlatformFile file) async {
    if (file.path == null) {
      return DocumentImportResult(
        fileName: file.name,
        success: false,
        error: 'No file path available',
      );
    }
    final destPath = await _copyToPdfDirectory(file.path!);
    final addedPath = await addPdfToLibrary(destPath);
    return DocumentImportResult(
      fileName: file.name,
      success: addedPath != null,
      filePath: addedPath,
      error: addedPath == null ? 'Failed to add PDF to library' : null,
    );
  }

  /// Add a PDF from bytes (web platform)
  Future<String?> _addPdfFromBytes(String fileName, List<int> bytes) async {
    try {
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final pageCount = await _getPdfPageCountFromBytes(bytes);

      // Insert into database with bytes
      final documentId = await _database.insertDocument(
        DocumentsCompanion(
          name: drift.Value(nameWithoutExt),
          filePath: drift.Value('web://$fileName'), // Placeholder path for web
          pdfBytes: drift.Value(bytes as Uint8List),
          lastModified: drift.Value(DateTime.now()),
          fileSize: drift.Value(bytes.length),
          pageCount: drift.Value(pageCount),
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
        'DocumentService: Added PDF from bytes: $nameWithoutExt (ID: $documentId)',
      );
      return 'web://$fileName';
    } catch (e, stackTrace) {
      debugPrint('DocumentService: Error adding PDF from bytes: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Get the page count of a PDF file
  Future<int> _getPdfPageCount(String filePath) async {
    try {
      final document = await FileAccessService.instance.openPdfDocument(
        filePath,
      );
      final pageCount = document.pagesCount;
      await document.close();
      return pageCount;
    } catch (e) {
      debugPrint('DocumentService: Could not read PDF page count: $e');
      return 0;
    }
  }

  /// Get the page count of a PDF from bytes (web platform)
  Future<int> _getPdfPageCountFromBytes(List<int> bytes) async {
    try {
      final document = await PdfDocument.openData(Uint8List.fromList(bytes));
      final pageCount = document.pagesCount;
      await document.close();
      return pageCount;
    } catch (e) {
      debugPrint('DocumentService: Could not read PDF page count from bytes: $e');
      return 0;
    }
  }

  /// Add a PDF file to the library database
  Future<String?> addPdfToLibrary(String filePath) async {
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
      final pageCount = await _getPdfPageCount(filePath);

      // Insert into database
      final documentId = await _database.insertDocument(
        DocumentsCompanion(
          name: drift.Value(fileName),
          filePath: drift.Value(filePath),
          lastModified: drift.Value(metadata.lastModified),
          fileSize: drift.Value(metadata.size),
          pageCount: drift.Value(pageCount),
        ),
      );

      // Create default settings for this document
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
        'DocumentService: Added PDF to library: $fileName (ID: $documentId)',
      );
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('DocumentService: Error adding PDF to library: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Scan the PDF directory and sync with database
  /// Useful for initial load or manual sync
  Future<void> scanAndSyncLibrary() async {
    // Skip on web (for development iteration only)
    if (kIsWeb) {
      debugPrint('DocumentService: Skipping library scan on web platform');
      return;
    }

    try {
      debugPrint('DocumentService: Scanning PDF directory...');

      final fileAccess = FileAccessService.instance;
      final pdfDirPath = await FileWatcherService.instance
          .getPdfDirectoryPath();

      if (!await fileAccess.directoryExists(pdfDirPath)) {
        debugPrint('DocumentService: PDF directory does not exist');
        return;
      }

      // Get all PDF files in directory (works for both SAF and local)
      final pdfFiles = await fileAccess.listPdfFiles(pdfDirPath);

      // Get all documents in database
      final dbDocuments = await _database.getAllDocuments();
      final dbPaths = dbDocuments.map((d) => d.filePath).toSet();

      // Add new PDFs to database
      for (final file in pdfFiles) {
        if (!dbPaths.contains(file.uri)) {
          await addPdfToLibrary(file.uri);
        }
      }

      // Remove deleted PDFs from database
      final filePaths = pdfFiles.map((f) => f.uri).toSet();
      for (final doc in dbDocuments) {
        // Skip web-stored PDFs (they don't have files on disk)
        if (doc.filePath.startsWith('web://')) continue;
        if (!filePaths.contains(doc.filePath)) {
          await _database.deleteDocument(doc.id);
          debugPrint(
            'DocumentService: Removed missing PDF from database: ${doc.name}',
          );
        }
      }

      debugPrint('DocumentService: Library sync complete');
    } catch (e, stackTrace) {
      debugPrint('DocumentService: Error scanning library: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Delete a PDF from library and optionally from disk
  Future<void> deletePdf(int documentId, {bool deleteFile = false}) async {
    try {
      final doc = await _database.getDocument(documentId);
      if (doc == null) return;

      if (deleteFile) {
        await FileAccessService.instance.deleteFile(doc.filePath);
      }

      await _database.deleteDocument(documentId);
      debugPrint('DocumentService: Deleted PDF: ${doc.name}');
    } catch (e) {
      debugPrint('DocumentService: Error deleting PDF: $e');
    }
  }

  /// Get the thumbnail cache directory path
  Future<String> _getThumbnailCachePath() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory(p.join(appDir.path, 'thumbnails'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  /// Get the thumbnail file path for a document
  Future<String> _getThumbnailPath(int documentId) async {
    final cachePath = await _getThumbnailCachePath();
    return p.join(cachePath, 'thumb_$documentId.png');
  }

  /// Generate a thumbnail for a PDF document
  /// Returns the thumbnail as bytes, or null if generation fails
  Future<Uint8List?> generateThumbnail(Document document) async {
    try {
      // Check if thumbnail already exists in cache (native platforms only)
      File? thumbFile;
      if (!kIsWeb) {
        final thumbPath = await _getThumbnailPath(document.id);
        thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          return await thumbFile.readAsBytes();
        }
      }

      // Open the PDF
      final pdfDoc = await FileAccessService.instance.openPdfDocument(
        document.filePath,
        pdfBytes: document.pdfBytes != null
            ? Uint8List.fromList(document.pdfBytes!)
            : null,
      );

      // Get the first page
      final page = await pdfDoc.getPage(1);

      // Render the page at a reasonable thumbnail size
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

      // Cache the thumbnail on native platforms
      if (!kIsWeb && thumbFile != null) {
        await thumbFile.writeAsBytes(pageImage.bytes);
      }

      return pageImage.bytes;
    } catch (e) {
      debugPrint('DocumentService: Error generating thumbnail: $e');
      return null;
    }
  }

  /// Get a cached thumbnail if available, otherwise return null
  Future<Uint8List?> getCachedThumbnail(int documentId) async {
    if (kIsWeb) return null;

    try {
      final thumbPath = await _getThumbnailPath(documentId);
      final thumbFile = File(thumbPath);
      if (await thumbFile.exists()) {
        return await thumbFile.readAsBytes();
      }
    } catch (e) {
      debugPrint('DocumentService: Error reading cached thumbnail: $e');
    }
    return null;
  }

  /// Delete the cached thumbnail for a document
  Future<void> deleteCachedThumbnail(int documentId) async {
    if (kIsWeb) return;

    try {
      final thumbPath = await _getThumbnailPath(documentId);
      final thumbFile = File(thumbPath);
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    } catch (e) {
      debugPrint('DocumentService: Error deleting cached thumbnail: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _pdfChangesSubscription?.cancel();
  }
}
