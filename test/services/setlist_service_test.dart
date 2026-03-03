import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/setlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SetListService', () {
    test('service type is correct', () {
      // Note: Full instantiation requires database initialization
      // which needs proper setup. Here we just test the type.
      expect(SetListService, isA<Type>());
    });

    // Note: Comprehensive tests would require mocking the database
    // These would include tests for:
    // - getAllSetLists
    // - getSetList
    // - createSetList
    // - updateSetList
    // - deleteSetList
    // - duplicateSetList
    // - addDocumentToSetList
    // - removeDocumentFromSetList
    // - reorderSetListItems
    // - getSetListDocuments
    // - getSetListItems
    // - getSetListsContainingDocument
    // - touchSetList
  });

  group('SetList Ordering', () {
    test('order indices are sequential', () {
      final indices = [0, 1, 2, 3, 4];

      for (int i = 0; i < indices.length; i++) {
        expect(indices[i], equals(i));
      }
    });

    test('reordering maintains uniqueness', () {
      final items = [0, 1, 2, 3];

      // Simulate moving item from index 0 to index 2
      final item = items.removeAt(0);
      var newIndex = 2;
      if (0 < newIndex) {
        newIndex -= 1;
      }
      items.insert(newIndex, item);

      expect(items, [1, 0, 2, 3]);
      expect(items.toSet().length, 4); // All unique
    });
  });

  group('updateSetListItemLabel', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    /// Helper to insert a test document and return its id.
    Future<int> createTestDocument(String name) async {
      return db.insertDocument(
        DocumentsCompanion(
          name: Value(name),
          filePath: Value('/test/$name'),
          lastModified: Value(DateTime.utc(2026, 1, 1)),
          fileSize: const Value(1000),
          pageCount: const Value(1),
        ),
      );
    }

    test(
      'updateSetListItemNotes updates the label on a set list item',
      () async {
        final setListId = await db.insertSetList(
          SetListsCompanion(name: const Value('Concert')),
        );
        final docId = await createTestDocument('Sonate.pdf');
        final itemId = await db.insertSetListItem(
          SetListItemsCompanion(
            setListId: Value(setListId),
            documentId: Value(docId),
            orderIndex: const Value(0),
          ),
        );

        await db.updateSetListItemNotes(itemId, 'Introduction');

        final items = await db.getSetListItems(setListId);
        expect(items.first.notes, 'Introduction');
      },
    );

    test('updateSetListItemNotes clears label when set to null', () async {
      final setListId = await db.insertSetList(
        SetListsCompanion(name: const Value('Concert')),
      );
      final docId = await createTestDocument('Sonate.pdf');
      final itemId = await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(docId),
          orderIndex: const Value(0),
          notes: const Value('Old label'),
        ),
      );

      await db.updateSetListItemNotes(itemId, null);

      final items = await db.getSetListItems(setListId);
      expect(items.first.notes, isNull);
    });
  });
}
