import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/file_access_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isSafUri', () {
    test('returns true for content:// URIs', () {
      expect(
        isSafUri(
          'content://com.android.externalstorage.documents/tree/primary%3AMusic',
        ),
        isTrue,
      );
      expect(
        isSafUri(
          'content://com.android.providers.downloads.documents/document/123',
        ),
        isTrue,
      );
    });

    test('returns false for regular file paths', () {
      expect(isSafUri('/home/user/documents/file.pdf'), isFalse);
      expect(isSafUri('/Users/test/pdfs/music.pdf'), isFalse);
      expect(isSafUri('C:\\Users\\test\\file.pdf'), isFalse);
    });

    test('returns false for web paths', () {
      expect(isSafUri('web://file.pdf'), isFalse);
      expect(isSafUri('http://example.com/file.pdf'), isFalse);
    });

    test('returns false for empty string', () {
      expect(isSafUri(''), isFalse);
    });
  });

  group('PdfFileInfo', () {
    test('creates instance with all fields', () {
      final now = DateTime.now();
      final info = PdfFileInfo(
        uri: '/path/to/file.pdf',
        name: 'file.pdf',
        size: 1024,
        lastModified: now,
      );

      expect(info.uri, '/path/to/file.pdf');
      expect(info.name, 'file.pdf');
      expect(info.size, 1024);
      expect(info.lastModified, now);
    });

    test('works with SAF URIs', () {
      final info = PdfFileInfo(
        uri:
            'content://com.android.externalstorage.documents/document/primary%3Afile.pdf',
        name: 'file.pdf',
        size: 2048,
        lastModified: DateTime(2024, 1, 15),
      );

      expect(isSafUri(info.uri), isTrue);
      expect(info.name, 'file.pdf');
    });
  });

  group('FileMetadata', () {
    test('creates instance with size and lastModified', () {
      final now = DateTime.now();
      final metadata = FileMetadata(size: 4096, lastModified: now);

      expect(metadata.size, 4096);
      expect(metadata.lastModified, now);
    });
  });

  group('FileAccessService local operations', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_access_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('listPdfFiles returns PDF files in directory', () async {
      // Create test files
      await File('${tempDir.path}/doc1.pdf').writeAsBytes([1, 2, 3]);
      await File('${tempDir.path}/doc2.pdf').writeAsBytes([4, 5, 6]);
      await File('${tempDir.path}/notes.txt').writeAsString('hello');
      await File('${tempDir.path}/image.png').writeAsBytes([7, 8, 9]);

      final files = await FileAccessService.instance.listPdfFiles(tempDir.path);

      expect(files.length, 2);
      expect(files.map((f) => f.name).toSet(), {'doc1.pdf', 'doc2.pdf'});
      for (final file in files) {
        expect(file.size, greaterThan(0));
        expect(file.uri, startsWith(tempDir.path));
      }
    });

    test('listPdfFiles returns empty list for nonexistent directory', () async {
      final files = await FileAccessService.instance.listPdfFiles(
        '${tempDir.path}/nonexistent',
      );
      expect(files, isEmpty);
    });

    test('listPdfFiles returns empty list for empty directory', () async {
      final files = await FileAccessService.instance.listPdfFiles(tempDir.path);
      expect(files, isEmpty);
    });

    test('listPdfFiles handles uppercase PDF extension', () async {
      await File('${tempDir.path}/doc.PDF').writeAsBytes([1, 2, 3]);

      final files = await FileAccessService.instance.listPdfFiles(tempDir.path);
      expect(files.length, 1);
      expect(files.first.name, 'doc.PDF');
    });

    test('readFileBytes reads file contents', () async {
      final testBytes = Uint8List.fromList([10, 20, 30, 40, 50]);
      await File('${tempDir.path}/test.pdf').writeAsBytes(testBytes);

      final bytes = await FileAccessService.instance.readFileBytes(
        '${tempDir.path}/test.pdf',
      );
      expect(bytes, testBytes);
    });

    test('writeFileToDirectory writes file and returns path', () async {
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final resultPath = await FileAccessService.instance.writeFileToDirectory(
        tempDir.path,
        'output.pdf',
        testBytes,
      );

      expect(resultPath, '${tempDir.path}${Platform.pathSeparator}output.pdf');
      expect(await File(resultPath).exists(), isTrue);
      expect(await File(resultPath).readAsBytes(), testBytes);
    });

    test('fileExists returns true for existing file', () async {
      await File('${tempDir.path}/exists.pdf').writeAsBytes([1]);

      final exists = await FileAccessService.instance.fileExists(
        '${tempDir.path}/exists.pdf',
      );
      expect(exists, isTrue);
    });

    test('fileExists returns false for nonexistent file', () async {
      final exists = await FileAccessService.instance.fileExists(
        '${tempDir.path}/nonexistent.pdf',
      );
      expect(exists, isFalse);
    });

    test('getFileMetadata returns correct size', () async {
      final testBytes = Uint8List.fromList(List.generate(100, (i) => i));
      await File('${tempDir.path}/meta.pdf').writeAsBytes(testBytes);

      final metadata = await FileAccessService.instance.getFileMetadata(
        '${tempDir.path}/meta.pdf',
      );

      expect(metadata.size, 100);
      expect(
        metadata.lastModified.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('deleteFile removes the file', () async {
      final filePath = '${tempDir.path}/to_delete.pdf';
      await File(filePath).writeAsBytes([1, 2, 3]);
      expect(await File(filePath).exists(), isTrue);

      await FileAccessService.instance.deleteFile(filePath);

      expect(await File(filePath).exists(), isFalse);
    });

    test('deleteFile does not throw for nonexistent file', () async {
      // Should not throw
      await FileAccessService.instance.deleteFile(
        '${tempDir.path}/nonexistent.pdf',
      );
    });

    test('directoryExists returns true for existing directory', () async {
      final exists = await FileAccessService.instance.directoryExists(
        tempDir.path,
      );
      expect(exists, isTrue);
    });

    test('directoryExists returns false for nonexistent directory', () async {
      final exists = await FileAccessService.instance.directoryExists(
        '${tempDir.path}/nonexistent',
      );
      expect(exists, isFalse);
    });
  });

  group('FileAccessService SAF routing', () {
    // These tests verify that SAF URIs are correctly identified and routed
    // through a mock platform channel that simulates SAF responses.

    const channel = MethodChannel('com.feuillet.app/saf');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'listPdfFiles':
                // Return an empty list as if the directory was empty
                return <Map>[];
              case 'fileExists':
                // Simulate file not found
                return false;
              case 'readFileBytes':
                return Uint8List.fromList([1, 2, 3]);
              case 'getFileMetadata':
                return {'size': 1024, 'lastModified': 1700000000000};
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('listPdfFiles routes SAF URIs to SAF channel', () async {
      final files = await FileAccessService.instance.listPdfFiles(
        'content://com.android.externalstorage.documents/tree/primary%3AMusic',
      );
      expect(files, isEmpty);
    });

    test('directoryExists uses SAF channel for content:// URIs', () async {
      final exists = await FileAccessService.instance.directoryExists(
        'content://com.android.externalstorage.documents/tree/primary%3AMusic',
      );
      // Mock returns empty list, which means directory is accessible
      expect(exists, isTrue);
    });

    test('fileExists uses SAF channel for content:// URIs', () async {
      final exists = await FileAccessService.instance.fileExists(
        'content://com.android.externalstorage.documents/document/primary%3Afile.pdf',
      );
      // Mock returns false
      expect(exists, isFalse);
    });

    test('readFileBytes uses SAF channel for content:// URIs', () async {
      final bytes = await FileAccessService.instance.readFileBytes(
        'content://com.android.externalstorage.documents/document/primary%3Afile.pdf',
      );
      expect(bytes, Uint8List.fromList([1, 2, 3]));
    });

    test('getFileMetadata uses SAF channel for content:// URIs', () async {
      final metadata = await FileAccessService.instance.getFileMetadata(
        'content://com.android.externalstorage.documents/document/primary%3Afile.pdf',
      );
      expect(metadata.size, 1024);
      expect(
        metadata.lastModified,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });
  });
}
