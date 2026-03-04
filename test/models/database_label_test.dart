import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Labels table', () {
    test('insert and retrieve a label', () async {
      await db.insertLabel(
        LabelsCompanion(
          name: const Value('Classical'),
          color: const Value(4294901760),
        ),
      );
      final labels = await db.getAllLabels();
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
      expect(labels.first.color, 4294901760);
    });

    test('label name is primary key — duplicate insert fails', () async {
      await db.insertLabel(LabelsCompanion(name: const Value('Classical')));
      expect(
        () => db.insertLabel(LabelsCompanion(name: const Value('Classical'))),
        throwsA(isA<SqliteException>()),
      );
    });

    test('delete label removes it', () async {
      await db.insertLabel(LabelsCompanion(name: const Value('Classical')));
      await db.deleteLabel('Classical');
      final labels = await db.getAllLabels();
      expect(labels, isEmpty);
    });

    test('update label color', () async {
      await db.insertLabel(LabelsCompanion(name: const Value('Classical')));
      await db.updateLabelColor('Classical', 4278190080);
      final labels = await db.getAllLabels();
      expect(labels.first.color, 4278190080);
    });

    test('rename label', () async {
      await db.insertLabel(
        LabelsCompanion(
          name: const Value('Classical'),
          color: const Value(4294901760),
        ),
      );
      await db.renameLabel('Classical', 'Baroque');
      final labels = await db.getAllLabels();
      expect(labels.length, 1);
      expect(labels.first.name, 'Baroque');
      expect(labels.first.color, 4294901760);
    });
  });

  group('DocumentLabels table', () {
    late int docId;

    setUp(() async {
      docId = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Bach Suite'),
          filePath: const Value('/docs/Bach.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(1024),
          pageCount: const Value(10),
        ),
      );
      await db.insertLabel(LabelsCompanion(name: const Value('Classical')));
      await db.insertLabel(LabelsCompanion(name: const Value('Bach')));
    });

    test('add label to document and retrieve', () async {
      await db.addLabelToDocument(docId, 'Classical');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });

    test('add multiple labels to document', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.addLabelToDocument(docId, 'Bach');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels.length, 2);
    });

    test('remove label from document', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.removeLabelFromDocument(docId, 'Classical');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });

    test('deleting document cascades to document_labels', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.deleteDocument(docId);
      final labels = await db.getAllLabels();
      expect(labels.length, 2);
    });

    test('deleting label cascades to document_labels', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.deleteLabel('Classical');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });

    test('rename label cascades to document_labels', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.renameLabel('Classical', 'Baroque');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels.length, 1);
      expect(labels.first.name, 'Baroque');
    });

    test(
      'getDocumentIdsWithAllLabels returns docs matching ALL labels',
      () async {
        final docId2 = await db.insertDocument(
          DocumentsCompanion(
            name: const Value('Mozart Sonata'),
            filePath: const Value('/docs/Mozart.pdf'),
            lastModified: Value(DateTime.now()),
            fileSize: const Value(2048),
            pageCount: const Value(20),
          ),
        );
        await db.addLabelToDocument(docId, 'Classical');
        await db.addLabelToDocument(docId, 'Bach');
        await db.addLabelToDocument(docId2, 'Classical');

        final ids = await db.getDocumentIdsWithAllLabels(['Classical', 'Bach']);
        expect(ids, [docId]);
      },
    );

    test('getDocumentIdsWithAllLabels with empty list returns empty', () async {
      final ids = await db.getDocumentIdsWithAllLabels([]);
      expect(ids, isEmpty);
    });

    test('getDocumentIdsWithAllLabels with single label', () async {
      await db.addLabelToDocument(docId, 'Classical');
      final ids = await db.getDocumentIdsWithAllLabels(['Classical']);
      expect(ids, [docId]);
    });

    test(
      'getDocumentIdsWithAllLabels returns empty when no doc matches all',
      () async {
        await db.addLabelToDocument(docId, 'Classical');
        // docId has only 'Classical', not 'Bach'
        final ids = await db.getDocumentIdsWithAllLabels(['Classical', 'Bach']);
        expect(ids, isEmpty);
      },
    );

    test('watchAllLabels emits updates after insert', () async {
      final emissions = <List<Label>>[];
      final sub = db.watchAllLabels().listen(emissions.add);

      // Wait for initial emission (setUp inserted 'Bach' and 'Classical')
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emissions.last.length, 2);

      // Insert a new label and verify stream emits updated list
      await db.insertLabel(LabelsCompanion(name: const Value('Jazz')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(emissions.last.length, 3);
      expect(emissions.last.map((l) => l.name), contains('Jazz'));

      await sub.cancel();
    });
  });
}
