import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rename_doc_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    SyncManager.resetInstance();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<int> insertDoc(String fileName, {String type = 'pdf'}) async {
    final path = '${tempDir.path}/$fileName';
    await File(path).writeAsString('fake content');
    return db.insertDocument(
      DocumentsCompanion(
        name: Value(fileName.split('.').first),
        filePath: Value(path),
        lastModified: Value(DateTime.utc(2026, 1, 1)),
        fileSize: const Value(1000),
        pageCount: const Value(3),
        documentType: Value(type),
      ),
    );
  }

  group('sidecarFileName', () {
    test('renames sidecar when document path changes', () {
      expect(
        sidecarFileName('/docs/Bach - Suite 1.pdf'),
        '/docs/Bach - Suite 1.feuillet.json',
      );
      expect(
        sidecarFileName('/docs/New Name.pdf'),
        '/docs/New Name.feuillet.json',
      );
    });
  });

  group('set list file path updates after rename', () {
    test('buildSetListFile uses current filePath from DB', () async {
      final docId = await insertDoc('Bach.pdf');

      // Create a set list referencing the document.
      final setListId = await db.insertSetList(
        SetListsCompanion(
          name: const Value('Concert'),
          modifiedAt: Value(DateTime.utc(2026, 1, 1)),
        ),
      );
      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(docId),
          orderIndex: const Value(0),
        ),
      );

      // Simulate rename: update DB to new path.
      final doc = await db.getDocument(docId);
      final newPath = '${tempDir.path}/New Name.pdf';
      await db.updateDocument(
        doc!.copyWith(name: 'New Name', filePath: newPath),
      );

      // Build the set list file and verify the relative path uses the new name.
      final setListFile = await buildSetListFile(db, setListId, tempDir.path);
      expect(setListFile, isNotNull);
      expect(setListFile!.items.first.documentPath, 'New Name.pdf');
    });
  });

  group('sidecar file rename on disk', () {
    test('sidecar file is renamed alongside document', () async {
      // Create score file and its sidecar.
      final scorePath = '${tempDir.path}/Bach.pdf';
      await File(scorePath).writeAsString('fake pdf');

      final oldSidecar = sidecarFileName(scorePath);
      await File(oldSidecar).writeAsString(jsonEncode({
        'version': 1,
        'modifiedAt': '2026-01-01T00:00:00.000Z',
        'layers': [],
      }));

      expect(await File(oldSidecar).exists(), isTrue);

      // Simulate rename on disk.
      final newPath = '${tempDir.path}/Renamed.pdf';
      await File(scorePath).rename(newPath);
      await File(oldSidecar).rename(sidecarFileName(newPath));

      expect(await File(scorePath).exists(), isFalse);
      expect(await File(newPath).exists(), isTrue);
      expect(await File(oldSidecar).exists(), isFalse);
      expect(await File(sidecarFileName(newPath)).exists(), isTrue);

      // Verify the sidecar content is preserved.
      final content = await File(sidecarFileName(newPath)).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['version'], 1);
    });
  });

  group('set list import resolves renamed paths', () {
    test('importSetListFile matches updated file paths', () async {
      // Insert a document with the "new" path (post-rename).
      final newPath = '${tempDir.path}/Renamed.pdf';
      await File(newPath).writeAsString('fake pdf');
      final docId = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Renamed'),
          filePath: Value(newPath),
          lastModified: Value(DateTime.utc(2026, 1, 1)),
          fileSize: const Value(1000),
          pageCount: const Value(3),
        ),
      );

      // Import a set list file that references the new name.
      final setListFile = SetListFile(
        version: 1,
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Concert',
        items: [
          SetListFileItem(
            documentPath: 'Renamed.pdf',
            orderIndex: 0,
          ),
        ],
      );

      final setListId = await importSetListFile(
        db,
        setListFile,
        tempDir.path,
      );
      expect(setListId, isNotNull);

      final items = await db.getSetListItems(setListId!);
      expect(items.length, 1);
      expect(items.first.documentId, docId);
    });
  });
}
