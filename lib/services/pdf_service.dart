import 'dart:io';
import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:watcher/watcher.dart';
import '../models/database.dart';
import 'database_service.dart';
import 'file_watcher_service.dart';

/// Service to manage PDF files and library operations
class PdfService {
  PdfService._() {
    _initialize();
  }

  static final PdfService instance = PdfService._();

  StreamSubscription? _pdfChangesSubscription;
  final _database = DatabaseService.instance.database;

  /// Initialize the service and set up file watchers
  void _initialize() {
    // Skip file watching on web (for development iteration only)
    if (kIsWeb) {
      debugPrint('PdfService: Skipping file watcher on web platform');
      return;
    }

    // Listen to PDF directory changes from Syncthing
    _pdfChangesSubscription = FileWatcherService.instance.pdfChanges.listen(
      _handlePdfDirectoryChange,
      onError: (error) {
        debugPrint('PdfService: Error in PDF watcher: $error');
      },
    );
  }

  /// Handle PDF directory changes detected by file watcher
  Future<void> _handlePdfDirectoryChange(WatchEvent event) async {
    debugPrint(
      'PdfService: PDF directory changed: ${event.type} - ${event.path}',
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
        debugPrint('PdfService: PDF already in database: $filePath');
        return;
      }

      // Add to database
      await addPdfToLibrary(filePath);
      debugPrint('PdfService: Added new PDF from Syncthing: $filePath');
    } catch (e) {
      debugPrint('PdfService: Error handling new PDF: $e');
    }
  }

  /// Find a document by file path
  Future<Document?> _findDocumentByPath(String filePath) async {
    final docs = await _database.getAllDocuments();
    return docs.cast<Document?>().firstWhere(
      (d) => d?.filePath == filePath,
      orElse: () => null,
    );
  }

  /// Handle a PDF file removed by Syncthing
  Future<void> _handleRemovedPdf(String filePath) async {
    try {
      final doc = await _findDocumentByPath(filePath);
      if (doc != null) {
        await _database.deleteDocument(doc.id);
        debugPrint('PdfService: Removed PDF from database: $filePath');
      }
    } catch (e) {
      debugPrint('PdfService: Error handling removed PDF: $e');
    }
  }

  /// Handle a PDF file modified by Syncthing
  Future<void> _handleModifiedPdf(String filePath) async {
    try {
      final doc = await _findDocumentByPath(filePath);
      if (doc != null) {
        final file = File(filePath);
        final stat = await file.stat();

        await _database.updateDocument(
          doc.copyWith(lastModified: stat.modified, fileSize: stat.size),
        );
        debugPrint('PdfService: Updated PDF metadata: $filePath');
      }
    } catch (e) {
      debugPrint('PdfService: Error handling modified PDF: $e');
    }
  }

  /// Copy a file to the PDF directory with a unique name if needed
  Future<String> _copyToPdfDirectory(String sourcePath) async {
    final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
    final fileName = p.basename(sourcePath);
    final destPath = p.join(pdfDir, fileName);

    // Check if file already exists
    final destFile = File(destPath);
    if (await destFile.exists()) {
      // Generate unique name with timestamp
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueName = '${nameWithoutExt}_$timestamp$ext';
      final uniquePath = p.join(pdfDir, uniqueName);
      await File(sourcePath).copy(uniquePath);
      return uniquePath;
    } else {
      await File(sourcePath).copy(destPath);
      return destPath;
    }
  }

  /// Import a PDF file using file picker
  Future<String?> importPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: kIsWeb, // Load bytes on web
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;

      // On web, use bytes-based approach
      if (kIsWeb) {
        if (file.bytes == null) {
          debugPrint('PdfService: No bytes available for web import');
          return null;
        }
        return await _addPdfFromBytes(file.name, file.bytes!);
      }

      // On native platforms, use file path approach
      if (file.path == null) {
        return null;
      }

      final destPath = await _copyToPdfDirectory(file.path!);
      return await addPdfToLibrary(destPath);
    } catch (e) {
      debugPrint('PdfService: Error importing PDF: $e');
      return null;
    }
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
        'PdfService: Added PDF from bytes: $nameWithoutExt (ID: $documentId)',
      );
      return 'web://$fileName';
    } catch (e, stackTrace) {
      debugPrint('PdfService: Error adding PDF from bytes: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Get the page count of a PDF file
  Future<int> _getPdfPageCount(String filePath) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      final pageCount = document.pagesCount;
      await document.close();
      return pageCount;
    } catch (e) {
      debugPrint('PdfService: Could not read PDF page count: $e');
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
      debugPrint('PdfService: Could not read PDF page count from bytes: $e');
      return 0;
    }
  }

  /// Add a PDF file to the library database
  Future<String?> addPdfToLibrary(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('PdfService: File does not exist: $filePath');
        return null;
      }

      final stat = await file.stat();
      final fileName = p.basenameWithoutExtension(filePath);
      final pageCount = await _getPdfPageCount(filePath);

      // Insert into database
      final documentId = await _database.insertDocument(
        DocumentsCompanion(
          name: drift.Value(fileName),
          filePath: drift.Value(filePath),
          lastModified: drift.Value(stat.modified),
          fileSize: drift.Value(stat.size),
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
        'PdfService: Added PDF to library: $fileName (ID: $documentId)',
      );
      return filePath;
    } catch (e, stackTrace) {
      debugPrint('PdfService: Error adding PDF to library: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Scan the PDF directory and sync with database
  /// Useful for initial load or manual sync
  Future<void> scanAndSyncLibrary() async {
    // Skip on web (for development iteration only)
    if (kIsWeb) {
      debugPrint('PdfService: Skipping library scan on web platform');
      return;
    }

    try {
      debugPrint('PdfService: Scanning PDF directory...');

      final pdfDirPath = await FileWatcherService.instance
          .getPdfDirectoryPath();
      final pdfDir = Directory(pdfDirPath);

      if (!await pdfDir.exists()) {
        debugPrint('PdfService: PDF directory does not exist');
        return;
      }

      // Get all PDF files in directory
      final pdfFiles = await pdfDir
          .list()
          .where(
            (entity) =>
                entity is File &&
                p.extension(entity.path).toLowerCase() == '.pdf',
          )
          .cast<File>()
          .toList();

      // Get all documents in database
      final dbDocuments = await _database.getAllDocuments();
      final dbPaths = dbDocuments.map((d) => d.filePath).toSet();

      // Add new PDFs to database
      for (final file in pdfFiles) {
        if (!dbPaths.contains(file.path)) {
          await addPdfToLibrary(file.path);
        }
      }

      // Remove deleted PDFs from database
      final filePaths = pdfFiles.map((f) => f.path).toSet();
      for (final doc in dbDocuments) {
        if (!filePaths.contains(doc.filePath)) {
          await _database.deleteDocument(doc.id);
          debugPrint(
            'PdfService: Removed missing PDF from database: ${doc.name}',
          );
        }
      }

      debugPrint('PdfService: Library sync complete');
    } catch (e, stackTrace) {
      debugPrint('PdfService: Error scanning library: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Delete a PDF from library and optionally from disk
  Future<void> deletePdf(int documentId, {bool deleteFile = false}) async {
    try {
      final doc = await _database.getDocument(documentId);
      if (doc == null) return;

      if (deleteFile) {
        final file = File(doc.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await _database.deleteDocument(documentId);
      debugPrint('PdfService: Deleted PDF: ${doc.name}');
    } catch (e) {
      debugPrint('PdfService: Error deleting PDF: $e');
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
      final PdfDocument pdfDoc;
      if (document.pdfBytes != null) {
        pdfDoc = await PdfDocument.openData(
          Uint8List.fromList(document.pdfBytes!),
        );
      } else {
        final file = File(document.filePath);
        if (!await file.exists()) {
          debugPrint('PdfService: PDF file not found: ${document.filePath}');
          return null;
        }
        pdfDoc = await PdfDocument.openFile(document.filePath);
      }

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
        debugPrint('PdfService: Failed to render page for thumbnail');
        return null;
      }

      // Cache the thumbnail on native platforms
      if (!kIsWeb && thumbFile != null) {
        await thumbFile.writeAsBytes(pageImage.bytes);
      }

      return pageImage.bytes;
    } catch (e) {
      debugPrint('PdfService: Error generating thumbnail: $e');
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
      debugPrint('PdfService: Error reading cached thumbnail: $e');
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
      debugPrint('PdfService: Error deleting cached thumbnail: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _pdfChangesSubscription?.cancel();
  }
}
