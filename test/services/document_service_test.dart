import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/document_service.dart';
import 'package:feuillet/models/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentService', () {
    test('service type is correct', () {
      // Note: Full instantiation requires database and file system initialization
      // Testing the actual service requires proper setup/mocking
      expect(true, isTrue); // Placeholder test
    });

    // Note: More comprehensive tests would require:
    // - Mocking the file system
    // - Mocking the database
    // - Mocking the file watcher service
    //
    // These would include tests for:
    // - importDocuments
    // - importDocumentsFromDroppedFiles
    // - scanAndSyncLibrary
    // - _handleNewPdf
    // - _handleRemovedPdf
    // - _handleModifiedPdf
    // - _getPageCount
    // - _generateUniqueFilename
  });

  group('Document File Operations', () {
    test('validates PDF extension - lowercase', () {
      final ext = 'file.pdf'.split('.').last.toLowerCase();
      expect(DocumentTypes.allExtensions.contains(ext), isTrue);
    });

    test('validates PDF extension - uppercase', () {
      final ext = 'file.PDF'.split('.').last.toLowerCase();
      expect(DocumentTypes.allExtensions.contains(ext), isTrue);
    });

    test('validates PDF extension - mixed case', () {
      final ext = 'file.Pdf'.split('.').last.toLowerCase();
      expect(DocumentTypes.allExtensions.contains(ext), isTrue);
    });

    test('validates image file extensions as acceptable', () {
      for (final filename in ['photo.jpg', 'image.jpeg', 'screenshot.png']) {
        final ext = filename.split('.').last.toLowerCase();
        expect(
          DocumentTypes.allExtensions.contains(ext),
          isTrue,
          reason: '$filename should be accepted',
        );
      }
    });

    test('validates image extensions are case-insensitive', () {
      for (final filename in ['photo.JPG', 'image.JPEG', 'screenshot.PNG']) {
        final ext = filename.split('.').last.toLowerCase();
        expect(
          DocumentTypes.allExtensions.contains(ext),
          isTrue,
          reason: '$filename should be accepted',
        );
      }
    });

    test('rejects unsupported file types', () {
      for (final filename in [
        'file.txt',
        'file.doc',
        'file.docx',
        'file.pptx',
      ]) {
        final ext = filename.split('.').last.toLowerCase();
        expect(
          DocumentTypes.allExtensions.contains(ext),
          isFalse,
          reason: '$filename should be rejected',
        );
      }
    });

    test('rejects files without extension', () {
      // A file named just 'file' would have ext == 'file'
      final ext = 'file'.split('.').last.toLowerCase();
      expect(DocumentTypes.allExtensions.contains(ext), isFalse);
    });

    test('rejects files with pdf in name but wrong extension', () {
      final ext1 = 'pdf_document.txt'.split('.').last.toLowerCase();
      expect(DocumentTypes.allExtensions.contains(ext1), isFalse);

      final ext2 = 'my.pdf.backup'.split('.').last.toLowerCase();
      expect(DocumentTypes.allExtensions.contains(ext2), isFalse);
    });
  });

  group('DocumentTypes', () {
    test('fromPath returns pdf for PDF files', () {
      expect(DocumentTypes.fromPath('file.pdf'), DocumentTypes.pdf);
      expect(DocumentTypes.fromPath('/path/to/file.pdf'), DocumentTypes.pdf);
    });

    test('fromPath returns image for image files', () {
      expect(DocumentTypes.fromPath('photo.jpg'), DocumentTypes.image);
      expect(DocumentTypes.fromPath('photo.jpeg'), DocumentTypes.image);
      expect(DocumentTypes.fromPath('photo.png'), DocumentTypes.image);
    });

    test('fromExtension handles extensions correctly', () {
      expect(DocumentTypes.fromExtension('pdf'), DocumentTypes.pdf);
      expect(DocumentTypes.fromExtension('jpg'), DocumentTypes.image);
      expect(DocumentTypes.fromExtension('jpeg'), DocumentTypes.image);
      expect(DocumentTypes.fromExtension('png'), DocumentTypes.image);
      expect(DocumentTypes.fromExtension('.jpg'), DocumentTypes.image);
    });

    test('allExtensions contains all supported types', () {
      expect(DocumentTypes.allExtensions, contains('pdf'));
      expect(DocumentTypes.allExtensions, contains('jpg'));
      expect(DocumentTypes.allExtensions, contains('jpeg'));
      expect(DocumentTypes.allExtensions, contains('png'));
    });
  });

  group('DocumentImportResult', () {
    test('creates success result correctly', () {
      const result = DocumentImportResult(
        fileName: 'test.pdf',
        success: true,
        filePath: '/path/to/test.pdf',
      );
      expect(result.fileName, 'test.pdf');
      expect(result.success, isTrue);
      expect(result.filePath, '/path/to/test.pdf');
      expect(result.error, isNull);
    });

    test('creates failure result correctly', () {
      const result = DocumentImportResult(
        fileName: 'test.pdf',
        success: false,
        error: 'File not found',
      );
      expect(result.fileName, 'test.pdf');
      expect(result.success, isFalse);
      expect(result.filePath, isNull);
      expect(result.error, 'File not found');
    });

    test('creates unsupported file type error result', () {
      const result = DocumentImportResult(
        fileName: 'document.txt',
        success: false,
        error: 'Unsupported file type. Supported: PDF, JPG, PNG',
      );
      expect(result.fileName, 'document.txt');
      expect(result.success, isFalse);
      expect(result.error, 'Unsupported file type. Supported: PDF, JPG, PNG');
    });

    test('creates empty path error result', () {
      const result = DocumentImportResult(
        fileName: 'test.pdf',
        success: false,
        error: 'No file path available',
      );
      expect(result.fileName, 'test.pdf');
      expect(result.success, isFalse);
      expect(result.error, 'No file path available');
    });
  });

  group('DocumentImportBatchResult', () {
    test('calculates counts correctly for all success', () {
      const results = DocumentImportBatchResult([
        DocumentImportResult(
          fileName: 'a.pdf',
          success: true,
          filePath: '/a.pdf',
        ),
        DocumentImportResult(
          fileName: 'b.pdf',
          success: true,
          filePath: '/b.pdf',
        ),
        DocumentImportResult(
          fileName: 'c.pdf',
          success: true,
          filePath: '/c.pdf',
        ),
      ]);

      expect(results.totalCount, 3);
      expect(results.successCount, 3);
      expect(results.failureCount, 0);
      expect(results.allSucceeded, isTrue);
      expect(results.hasFailures, isFalse);
      expect(results.failures, isEmpty);
    });

    test('calculates counts correctly for partial success', () {
      const results = DocumentImportBatchResult([
        DocumentImportResult(
          fileName: 'a.pdf',
          success: true,
          filePath: '/a.pdf',
        ),
        DocumentImportResult(
          fileName: 'b.pdf',
          success: false,
          error: 'Failed',
        ),
        DocumentImportResult(
          fileName: 'c.pdf',
          success: true,
          filePath: '/c.pdf',
        ),
      ]);

      expect(results.totalCount, 3);
      expect(results.successCount, 2);
      expect(results.failureCount, 1);
      expect(results.allSucceeded, isFalse);
      expect(results.hasFailures, isTrue);
      expect(results.failures.length, 1);
      expect(results.failures.first.fileName, 'b.pdf');
    });

    test('calculates counts correctly for all failures', () {
      const results = DocumentImportBatchResult([
        DocumentImportResult(
          fileName: 'a.pdf',
          success: false,
          error: 'Error 1',
        ),
        DocumentImportResult(
          fileName: 'b.pdf',
          success: false,
          error: 'Error 2',
        ),
      ]);

      expect(results.totalCount, 2);
      expect(results.successCount, 0);
      expect(results.failureCount, 2);
      expect(results.allSucceeded, isFalse);
      expect(results.hasFailures, isTrue);
      expect(results.failures.length, 2);
    });

    test('handles empty results', () {
      const results = DocumentImportBatchResult([]);

      expect(results.totalCount, 0);
      expect(results.successCount, 0);
      expect(results.failureCount, 0);
      expect(results.allSucceeded, isTrue);
      expect(results.hasFailures, isFalse);
    });

    test('handles mixed file types from drag-drop', () {
      // Simulates dropping a mix of supported and unsupported files
      const results = DocumentImportBatchResult([
        DocumentImportResult(
          fileName: 'doc1.pdf',
          success: true,
          filePath: '/doc1.pdf',
        ),
        DocumentImportResult(
          fileName: 'image.png',
          success: true,
          filePath: '/image.png',
        ),
        DocumentImportResult(
          fileName: 'doc2.pdf',
          success: true,
          filePath: '/doc2.pdf',
        ),
        DocumentImportResult(
          fileName: 'notes.txt',
          success: false,
          error: 'Unsupported file type. Supported: PDF, JPG, PNG',
        ),
      ]);

      expect(results.totalCount, 4);
      expect(results.successCount, 3);
      expect(results.failureCount, 1);
      expect(results.allSucceeded, isFalse);
      expect(results.hasFailures, isTrue);
      expect(results.failures.length, 1);

      final failedFileNames = results.failures.map((f) => f.fileName).toList();
      expect(failedFileNames, ['notes.txt']);
    });

    test('filters only failures from results', () {
      const results = DocumentImportBatchResult([
        DocumentImportResult(
          fileName: 'a.pdf',
          success: true,
          filePath: '/a.pdf',
        ),
        DocumentImportResult(
          fileName: 'b.txt',
          success: false,
          error: 'Unsupported file type. Supported: PDF, JPG, PNG',
        ),
        DocumentImportResult(
          fileName: 'c.pdf',
          success: false,
          error: 'Failed to add document',
        ),
      ]);

      final failures = results.failures;
      expect(failures.length, 2);
      expect(failures[0].fileName, 'b.txt');
      expect(
        failures[0].error,
        'Unsupported file type. Supported: PDF, JPG, PNG',
      );
      expect(failures[1].fileName, 'c.pdf');
      expect(failures[1].error, 'Failed to add document');
    });
  });
}
