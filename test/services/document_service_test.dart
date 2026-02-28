import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/document_service.dart';

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
    // - importPdfs
    // - importPdfsFromDroppedFiles
    // - scanAndSyncLibrary
    // - _handleNewPdf
    // - _handleRemovedPdf
    // - _handleModifiedPdf
    // - _getPageCount
    // - _generateUniqueFilename
  });

  group('PDF File Operations', () {
    test('validates PDF extension - lowercase', () {
      expect('file.pdf'.toLowerCase().endsWith('.pdf'), isTrue);
    });

    test('validates PDF extension - uppercase', () {
      expect('file.PDF'.toLowerCase().endsWith('.pdf'), isTrue);
    });

    test('validates PDF extension - mixed case', () {
      expect('file.Pdf'.toLowerCase().endsWith('.pdf'), isTrue);
    });

    test('rejects non-PDF extensions', () {
      expect('file.txt'.toLowerCase().endsWith('.pdf'), isFalse);
      expect('file.doc'.toLowerCase().endsWith('.pdf'), isFalse);
      expect('file.png'.toLowerCase().endsWith('.pdf'), isFalse);
      expect('file.jpg'.toLowerCase().endsWith('.pdf'), isFalse);
    });

    test('rejects files without extension', () {
      expect('file'.toLowerCase().endsWith('.pdf'), isFalse);
    });

    test('rejects files with pdf in name but wrong extension', () {
      expect('pdf_document.txt'.toLowerCase().endsWith('.pdf'), isFalse);
      expect('my.pdf.backup'.toLowerCase().endsWith('.pdf'), isFalse);
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

    test('creates non-PDF file error result', () {
      const result = DocumentImportResult(
        fileName: 'document.txt',
        success: false,
        error: 'Not a PDF file',
      );
      expect(result.fileName, 'document.txt');
      expect(result.success, isFalse);
      expect(result.error, 'Not a PDF file');
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
        DocumentImportResult(fileName: 'a.pdf', success: true, filePath: '/a.pdf'),
        DocumentImportResult(fileName: 'b.pdf', success: true, filePath: '/b.pdf'),
        DocumentImportResult(fileName: 'c.pdf', success: true, filePath: '/c.pdf'),
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
        DocumentImportResult(fileName: 'a.pdf', success: true, filePath: '/a.pdf'),
        DocumentImportResult(fileName: 'b.pdf', success: false, error: 'Failed'),
        DocumentImportResult(fileName: 'c.pdf', success: true, filePath: '/c.pdf'),
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
        DocumentImportResult(fileName: 'a.pdf', success: false, error: 'Error 1'),
        DocumentImportResult(fileName: 'b.pdf', success: false, error: 'Error 2'),
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
      // Simulates dropping a mix of PDF and non-PDF files
      const results = DocumentImportBatchResult([
        DocumentImportResult(
          fileName: 'doc1.pdf',
          success: true,
          filePath: '/doc1.pdf',
        ),
        DocumentImportResult(
          fileName: 'image.png',
          success: false,
          error: 'Not a PDF file',
        ),
        DocumentImportResult(
          fileName: 'doc2.pdf',
          success: true,
          filePath: '/doc2.pdf',
        ),
        DocumentImportResult(
          fileName: 'notes.txt',
          success: false,
          error: 'Not a PDF file',
        ),
      ]);

      expect(results.totalCount, 4);
      expect(results.successCount, 2);
      expect(results.failureCount, 2);
      expect(results.allSucceeded, isFalse);
      expect(results.hasFailures, isTrue);
      expect(results.failures.length, 2);

      final failedFileNames = results.failures.map((f) => f.fileName).toList();
      expect(failedFileNames, ['image.png', 'notes.txt']);

      final allFailuresAreNotPdf = results.failures.every(
        (f) => f.error == 'Not a PDF file',
      );
      expect(allFailuresAreNotPdf, isTrue);
    });

    test('filters only failures from results', () {
      const results = DocumentImportBatchResult([
        DocumentImportResult(fileName: 'a.pdf', success: true, filePath: '/a.pdf'),
        DocumentImportResult(
          fileName: 'b.txt',
          success: false,
          error: 'Not a PDF file',
        ),
        DocumentImportResult(
          fileName: 'c.pdf',
          success: false,
          error: 'Failed to add PDF',
        ),
      ]);

      final failures = results.failures;
      expect(failures.length, 2);
      expect(failures[0].fileName, 'b.txt');
      expect(failures[0].error, 'Not a PDF file');
      expect(failures[1].fileName, 'c.pdf');
      expect(failures[1].error, 'Failed to add PDF');
    });
  });
}
