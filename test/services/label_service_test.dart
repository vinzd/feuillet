import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/label_service.dart';

void main() {
  late AppDatabase db;
  late LabelService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = LabelService.forTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertDoc(String name, String path) async {
    return db.insertDocument(
      DocumentsCompanion(
        name: Value(name),
        filePath: Value(path),
        lastModified: Value(DateTime.now()),
        fileSize: const Value(1024),
        pageCount: const Value(10),
      ),
    );
  }

  group('createLabel', () {
    test('creates a new label', () async {
      await service.createLabel('Classical');
      final labels = await service.getAllLabels();
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });

    test('creates label with color', () async {
      await service.createLabel('Classical', color: 4294901760);
      final labels = await service.getAllLabels();
      expect(labels.first.color, 4294901760);
    });

    test('does not throw on duplicate', () async {
      await service.createLabel('Classical');
      await service.createLabel('Classical');
      final labels = await service.getAllLabels();
      expect(labels.length, 1);
    });
  });

  group('addLabelToDocument', () {
    test('associates label with document', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      final labels = await service.getLabelsForDocument(docId);
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });
  });

  group('addLabelToDocuments (batch)', () {
    test('adds label to multiple documents', () async {
      final id1 = await insertDoc('Bach', '/docs/Bach.pdf');
      final id2 = await insertDoc('Mozart', '/docs/Mozart.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocuments([id1, id2], 'Classical');

      final labels1 = await service.getLabelsForDocument(id1);
      final labels2 = await service.getLabelsForDocument(id2);
      expect(labels1.length, 1);
      expect(labels2.length, 1);
    });
  });

  group('removeLabelFromDocument', () {
    test('removes association', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      await service.removeLabelFromDocument(docId, 'Classical');
      final labels = await service.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });
  });

  group('deleteLabel', () {
    test('deletes label and associations', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      await service.deleteLabel('Classical');

      final allLabels = await service.getAllLabels();
      expect(allLabels, isEmpty);
      final docLabels = await service.getLabelsForDocument(docId);
      expect(docLabels, isEmpty);
    });
  });

  group('updateLabelColor', () {
    test('updates color', () async {
      await service.createLabel('Classical');
      await service.updateLabelColor('Classical', 4278190080);
      final labels = await service.getAllLabels();
      expect(labels.first.color, 4278190080);
    });
  });

  group('renameLabel', () {
    test('renames and preserves associations', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      await service.renameLabel('Classical', 'Baroque');

      final labels = await service.getLabelsForDocument(docId);
      expect(labels.first.name, 'Baroque');
    });
  });

  group('getDocumentIdsWithAllLabels', () {
    test('AND filter returns only docs with all labels', () async {
      final id1 = await insertDoc('Bach', '/docs/Bach.pdf');
      final id2 = await insertDoc('Mozart', '/docs/Mozart.pdf');
      await service.createLabel('Classical');
      await service.createLabel('Bach');
      await service.addLabelToDocument(id1, 'Classical');
      await service.addLabelToDocument(id1, 'Bach');
      await service.addLabelToDocument(id2, 'Classical');

      final ids = await service.getDocumentIdsWithAllLabels([
        'Classical',
        'Bach',
      ]);
      expect(ids, [id1]);
    });

    test('empty label list returns empty', () async {
      final ids = await service.getDocumentIdsWithAllLabels([]);
      expect(ids, isEmpty);
    });
  });

  group('ensureLabelsFromPath', () {
    test('creates labels from subdirectory segments', () async {
      final docId = await insertDoc(
        'Bach Suite',
        '/music/pdfs/Classical/Bach/Suite.pdf',
      );
      await service.ensureLabelsFromPath(
        docId,
        '/music/pdfs/Classical/Bach/Suite.pdf',
        '/music/pdfs',
      );

      final labels = await service.getLabelsForDocument(docId);
      final names = labels.map((l) => l.name).toSet();
      expect(names, {'Bach', 'Classical'});
    });

    test('no labels for files at root', () async {
      final docId = await insertDoc('Suite', '/music/pdfs/Suite.pdf');
      await service.ensureLabelsFromPath(
        docId,
        '/music/pdfs/Suite.pdf',
        '/music/pdfs',
      );

      final labels = await service.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });

    test('handles trailing slash on pdfDir', () async {
      final docId = await insertDoc(
        'Bach Suite',
        '/music/pdfs/Classical/Suite.pdf',
      );
      await service.ensureLabelsFromPath(
        docId,
        '/music/pdfs/Classical/Suite.pdf',
        '/music/pdfs/',
      );

      final labels = await service.getLabelsForDocument(docId);
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });
  });
}
