import 'package:flutter_test/flutter_test.dart';

void main() {
  group('File Path Operations', () {
    test('PDF file extension detection', () {
      final pdfFiles = [
        'document.pdf',
        'score.PDF',
        'music.Pdf',
        '/path/to/file.pdf',
      ];

      for (final file in pdfFiles) {
        expect(file.toLowerCase().endsWith('.pdf'), isTrue);
      }
    });

    test('non-PDF file rejection', () {
      final nonPdfFiles = [
        'document.txt',
        'image.jpg',
        'audio.mp3',
        'video.mp4',
      ];

      for (final file in nonPdfFiles) {
        expect(file.toLowerCase().endsWith('.pdf'), isFalse);
      }
    });

    test('filename extraction from path', () {
      final path = '/path/to/document.pdf';
      final filename = path.split('/').last;

      expect(filename, 'document.pdf');
    });

    test('filename without extension', () {
      final filename = 'document.pdf';
      final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));

      expect(nameWithoutExt, 'document');
    });

    test('file extension extraction', () {
      final filename = 'document.pdf';
      final extension = filename.substring(filename.lastIndexOf('.'));

      expect(extension, '.pdf');
    });

    test('handling filenames with multiple dots', () {
      final filename = 'my.document.v2.pdf';
      final extension = filename.substring(filename.lastIndexOf('.'));
      final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));

      expect(extension, '.pdf');
      expect(nameWithoutExt, 'my.document.v2');
    });
  });

  group('File Size Formatting', () {
    test('formats bytes correctly', () {
      expect(_formatFileSize(0), '0 B');
      expect(_formatFileSize(1023), '1023 B');
      expect(_formatFileSize(1024), '1.0 KB');
      expect(_formatFileSize(1536), '1.5 KB');
      expect(_formatFileSize(1048576), '1.0 MB');
      expect(_formatFileSize(1073741824), '1.0 GB');
    });

    test('handles large file sizes', () {
      final size = _formatFileSize(5368709120); // 5 GB
      expect(size, contains('GB'));
    });

    test('handles zero and negative sizes', () {
      expect(_formatFileSize(0), '0 B');
      expect(_formatFileSize(-1), '0 B'); // Negative should be treated as 0
    });
  });

  group('Filename Sanitization', () {
    test('removes invalid characters', () {
      final invalidChars = ['/', '\\', ':', '*', '?', '"', '<', '>', '|'];

      for (final char in invalidChars) {
        final filename = 'test${char}file.pdf';
        final sanitized = filename.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');

        expect(sanitized, 'test_file.pdf');
      }
    });

    test('handles unicode characters', () {
      final filename = 'Für Elise.pdf';

      expect(filename, isNotEmpty);
      expect(filename.contains('Für'), isTrue);
    });

    test('prevents empty filenames', () {
      final filename = '';
      final result = filename.isEmpty ? 'untitled.pdf' : filename;

      expect(result, 'untitled.pdf');
    });
  });

  group('Duplicate Filename Handling', () {
    test('generates unique filename with counter', () {
      final existingFiles = ['document.pdf', 'document (1).pdf'];
      final newFilename = 'document.pdf';

      // Check if file exists
      var counter = 0;
      var uniqueName = newFilename;
      while (existingFiles.contains(uniqueName)) {
        counter++;
        final nameWithoutExt = newFilename.substring(0, newFilename.lastIndexOf('.'));
        final ext = newFilename.substring(newFilename.lastIndexOf('.'));
        uniqueName = '$nameWithoutExt ($counter)$ext';
      }

      expect(uniqueName, 'document (2).pdf');
    });
  });
}

// Helper function to format file size
String _formatFileSize(int bytes) {
  if (bytes < 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
}
