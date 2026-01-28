import 'dart:io';
import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
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
    debugPrint('PdfService: PDF directory changed: ${event.type} - ${event.path}');

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

        await _database.updateDocument(doc.copyWith(
          lastModified: stat.modified,
          fileSize: stat.size,
        ));
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
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return null;
      }

      final sourcePath = result.files.first.path!;
      final destPath = await _copyToPdfDirectory(sourcePath);
      return await addPdfToLibrary(destPath);
    } catch (e) {
      debugPrint('PdfService: Error importing PDF: $e');
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

      debugPrint('PdfService: Added PDF to library: $fileName (ID: $documentId)');
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
    try {
      debugPrint('PdfService: Scanning PDF directory...');

      final pdfDirPath = await FileWatcherService.instance.getPdfDirectoryPath();
      final pdfDir = Directory(pdfDirPath);

      if (!await pdfDir.exists()) {
        debugPrint('PdfService: PDF directory does not exist');
        return;
      }

      // Get all PDF files in directory
      final pdfFiles = await pdfDir
          .list()
          .where((entity) =>
              entity is File && p.extension(entity.path).toLowerCase() == '.pdf')
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
          debugPrint('PdfService: Removed missing PDF from database: ${doc.name}');
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

  /// Clean up resources
  void dispose() {
    _pdfChangesSubscription?.cancel();
  }
}
