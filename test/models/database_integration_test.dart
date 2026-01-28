import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/models/database.dart';

/// Creates an in-memory database for testing
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      // Enable foreign keys in tests
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    // Ensure tables are created
    await db.customStatement('SELECT 1');
  });

  tearDown(() async {
    await db.close();
  });

  group('Document Settings Operations', () {
    late int documentId;

    setUp(() async {
      // Create a test document first
      documentId = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Test Document'),
          filePath: const Value('/path/to/test.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(1024),
          pageCount: const Value(10),
        ),
      );
    });

    test('getDocumentSettings returns null when no settings exist', () async {
      final settings = await db.getDocumentSettings(documentId);
      expect(settings, isNull);
    });

    test('insertOrUpdateDocumentSettings creates new settings', () async {
      final settingsId = await db.insertOrUpdateDocumentSettings(
        DocumentSettingsCompanion(
          documentId: Value(documentId),
          zoomLevel: const Value(1.5),
          brightness: const Value(0.1),
          contrast: const Value(1.2),
          currentPage: const Value(5),
        ),
      );

      expect(settingsId, greaterThan(0));

      final retrieved = await db.getDocumentSettings(documentId);
      expect(retrieved, isNotNull);
      expect(retrieved!.documentId, documentId);
      expect(retrieved.zoomLevel, 1.5);
      expect(retrieved.brightness, 0.1);
      expect(retrieved.contrast, 1.2);
      expect(retrieved.currentPage, 5);
    });

    test('insertOrUpdateDocumentSettings updates existing settings', () async {
      // Insert initial settings
      await db.insertOrUpdateDocumentSettings(
        DocumentSettingsCompanion(
          documentId: Value(documentId),
          zoomLevel: const Value(1.0),
          brightness: const Value(0.0),
          contrast: const Value(1.0),
          currentPage: const Value(0),
        ),
      );

      // Update settings
      await db.insertOrUpdateDocumentSettings(
        DocumentSettingsCompanion(
          documentId: Value(documentId),
          zoomLevel: const Value(2.0),
          brightness: const Value(0.5),
          contrast: const Value(1.5),
          currentPage: const Value(3),
        ),
      );

      final settings = await db.getDocumentSettings(documentId);
      expect(settings, isNotNull);
      expect(settings!.zoomLevel, 2.0);
      expect(settings.brightness, 0.5);
      expect(settings.contrast, 1.5);
      expect(settings.currentPage, 3);
    });

    test('multiple saves do not create duplicate settings records', () async {
      // Save settings multiple times
      for (int i = 0; i < 5; i++) {
        await db.insertOrUpdateDocumentSettings(
          DocumentSettingsCompanion(
            documentId: Value(documentId),
            zoomLevel: Value(1.0 + i * 0.1),
            brightness: const Value(0.0),
            contrast: const Value(1.0),
            currentPage: Value(i),
          ),
        );
      }

      // Count records in document_settings for this document
      final allSettings = await (db.select(
        db.documentSettings,
      )..where((s) => s.documentId.equals(documentId))).get();

      expect(
        allSettings.length,
        1,
        reason: 'Should only have one settings record per document',
      );

      // Verify the last update is stored
      final settings = await db.getDocumentSettings(documentId);
      expect(settings!.zoomLevel, closeTo(1.4, 0.01));
      expect(settings.currentPage, 4);
    });

    test('getDocumentSettings handles multiple records gracefully', () async {
      // Directly insert multiple records to simulate corrupt data
      // (This tests the fix for "Bad state: Too many elements" error)
      await db
          .into(db.documentSettings)
          .insert(
            DocumentSettingsCompanion(
              documentId: Value(documentId),
              zoomLevel: const Value(1.0),
              brightness: const Value(0.0),
              contrast: const Value(1.0),
              currentPage: const Value(0),
            ),
          );

      await db
          .into(db.documentSettings)
          .insert(
            DocumentSettingsCompanion(
              documentId: Value(documentId),
              zoomLevel: const Value(2.0),
              brightness: const Value(0.5),
              contrast: const Value(1.5),
              currentPage: const Value(5),
            ),
          );

      // This should NOT throw "Bad state: Too many elements"
      // It should return the first record found
      final settings = await db.getDocumentSettings(documentId);

      expect(settings, isNotNull);
      // Should return one of the settings (first found with limit(1))
      expect(settings!.documentId, documentId);
    });

    test('settings are deleted when document is deleted (cascade)', () async {
      // Create settings for the document
      await db.insertOrUpdateDocumentSettings(
        DocumentSettingsCompanion(
          documentId: Value(documentId),
          zoomLevel: const Value(1.5),
          brightness: const Value(0.1),
          contrast: const Value(1.2),
          currentPage: const Value(5),
        ),
      );

      // Verify settings exist
      var settings = await db.getDocumentSettings(documentId);
      expect(settings, isNotNull);

      // Delete the document
      await db.deleteDocument(documentId);

      // Settings should be deleted due to cascade
      settings = await db.getDocumentSettings(documentId);
      expect(settings, isNull);
    });
  });

  group('Document Operations', () {
    test('insertDocument creates a new document', () async {
      final id = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('My PDF'),
          filePath: const Value('/path/to/my.pdf'),
          lastModified: Value(DateTime(2024, 1, 15)),
          fileSize: const Value(2048),
          pageCount: const Value(20),
        ),
      );

      expect(id, greaterThan(0));

      final doc = await db.getDocument(id);
      expect(doc, isNotNull);
      expect(doc!.name, 'My PDF');
      expect(doc.pageCount, 20);
    });

    test('getAllDocuments returns all documents', () async {
      await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Doc 1'),
          filePath: const Value('/path/to/1.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(1000),
        ),
      );

      await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Doc 2'),
          filePath: const Value('/path/to/2.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(2000),
        ),
      );

      final docs = await db.getAllDocuments();
      expect(docs.length, 2);
    });

    test('getDocument returns null for non-existent id', () async {
      final doc = await db.getDocument(999);
      expect(doc, isNull);
    });

    test('deleteDocument removes the document', () async {
      final id = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('To Delete'),
          filePath: const Value('/path/to/delete.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(500),
        ),
      );

      await db.deleteDocument(id);

      final doc = await db.getDocument(id);
      expect(doc, isNull);
    });
  });

  group('Annotation Layer Operations', () {
    late int documentId;

    setUp(() async {
      documentId = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Annotated Doc'),
          filePath: const Value('/path/to/annotated.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(1024),
        ),
      );
    });

    test('insertAnnotationLayer creates a layer', () async {
      final layerId = await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(documentId),
          name: const Value('Layer 1'),
          orderIndex: const Value(0),
        ),
      );

      expect(layerId, greaterThan(0));

      final layers = await db.getAnnotationLayers(documentId);
      expect(layers.length, 1);
      expect(layers.first.name, 'Layer 1');
    });

    test('getAnnotationLayers returns layers in order', () async {
      await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(documentId),
          name: const Value('Layer C'),
          orderIndex: const Value(2),
        ),
      );

      await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(documentId),
          name: const Value('Layer A'),
          orderIndex: const Value(0),
        ),
      );

      await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(documentId),
          name: const Value('Layer B'),
          orderIndex: const Value(1),
        ),
      );

      final layers = await db.getAnnotationLayers(documentId);
      expect(layers.length, 3);
      expect(layers[0].name, 'Layer A');
      expect(layers[1].name, 'Layer B');
      expect(layers[2].name, 'Layer C');
    });

    test('annotation layers are deleted when document is deleted', () async {
      await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(documentId),
          name: const Value('Layer 1'),
          orderIndex: const Value(0),
        ),
      );

      var layers = await db.getAnnotationLayers(documentId);
      expect(layers.length, 1);

      await db.deleteDocument(documentId);

      layers = await db.getAnnotationLayers(documentId);
      expect(layers.length, 0);
    });
  });

  group('SetList Operations', () {
    test('insertSetList creates a set list', () async {
      final id = await db.insertSetList(
        SetListsCompanion(
          name: const Value('Concert Program'),
          description: const Value('Spring concert'),
        ),
      );

      expect(id, greaterThan(0));

      final setList = await db.getSetList(id);
      expect(setList, isNotNull);
      expect(setList!.name, 'Concert Program');
    });

    test('getAllSetLists returns all set lists', () async {
      await db.insertSetList(SetListsCompanion(name: const Value('Set 1')));

      await db.insertSetList(SetListsCompanion(name: const Value('Set 2')));

      final setLists = await db.getAllSetLists();
      expect(setLists.length, 2);
    });

    test('deleteSetList removes the set list', () async {
      final id = await db.insertSetList(
        SetListsCompanion(name: const Value('To Delete')),
      );

      await db.deleteSetList(id);

      final setList = await db.getSetList(id);
      expect(setList, isNull);
    });
  });

  group('SetList Items', () {
    late int setListId;
    late int doc1Id;
    late int doc2Id;

    setUp(() async {
      setListId = await db.insertSetList(
        SetListsCompanion(name: const Value('Test Set')),
      );

      doc1Id = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Doc 1'),
          filePath: const Value('/path/1.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(100),
        ),
      );

      doc2Id = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Doc 2'),
          filePath: const Value('/path/2.pdf'),
          lastModified: Value(DateTime.now()),
          fileSize: const Value(200),
        ),
      );
    });

    test('insertSetListItem adds document to set list', () async {
      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(doc1Id),
          orderIndex: const Value(0),
        ),
      );

      final items = await db.getSetListItems(setListId);
      expect(items.length, 1);
      expect(items.first.documentId, doc1Id);
    });

    test('getSetListItems returns items in order', () async {
      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(doc2Id),
          orderIndex: const Value(1),
        ),
      );

      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(doc1Id),
          orderIndex: const Value(0),
        ),
      );

      final items = await db.getSetListItems(setListId);
      expect(items.length, 2);
      expect(items[0].documentId, doc1Id);
      expect(items[1].documentId, doc2Id);
    });

    test('set list items are deleted when set list is deleted', () async {
      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(doc1Id),
          orderIndex: const Value(0),
        ),
      );

      await db.deleteSetList(setListId);

      final items = await db.getSetListItems(setListId);
      expect(items.length, 0);
    });

    test('getDocumentsInSetList returns documents', () async {
      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(doc1Id),
          orderIndex: const Value(0),
        ),
      );

      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(doc2Id),
          orderIndex: const Value(1),
        ),
      );

      final docs = await db.getDocumentsInSetList(setListId);
      expect(docs.length, 2);
    });
  });
}
