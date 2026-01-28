import 'package:drift/drift.dart' as drift;
import '../models/database.dart';
import 'database_service.dart';

/// Service to manage set lists
class SetListService {
  final AppDatabase _database = DatabaseService.instance.database;

  /// Get all set lists
  Future<List<SetList>> getAllSetLists() async {
    return await _database.getAllSetLists();
  }

  /// Get a specific set list
  Future<SetList?> getSetList(int id) async {
    return await _database.getSetList(id);
  }

  /// Create a new set list
  Future<int> createSetList(String name, {String? description}) async {
    return await _database.insertSetList(
      SetListsCompanion(
        name: drift.Value(name),
        description: drift.Value(description),
      ),
    );
  }

  /// Update a set list
  Future<void> updateSetList(SetList setList) async {
    await _database.updateSetList(setList);
  }

  /// Delete a set list
  Future<void> deleteSetList(int id) async {
    await _database.deleteSetList(id);
  }

  /// Get items in a set list
  Future<List<SetListItem>> getSetListItems(int setListId) async {
    return await _database.getSetListItems(setListId);
  }

  /// Get documents in a set list
  Future<List<Document>> getSetListDocuments(int setListId) async {
    return await _database.getDocumentsInSetList(setListId);
  }

  /// Add a document to a set list
  Future<int> addDocumentToSetList({
    required int setListId,
    required int documentId,
    String? notes,
  }) async {
    // Get current items to determine order index
    final items = await getSetListItems(setListId);
    final orderIndex = items.length;

    return await _database.insertSetListItem(
      SetListItemsCompanion(
        setListId: drift.Value(setListId),
        documentId: drift.Value(documentId),
        orderIndex: drift.Value(orderIndex),
        notes: drift.Value(notes),
      ),
    );
  }

  /// Remove a document from a set list
  Future<void> removeDocumentFromSetList(int itemId) async {
    await _database.deleteSetListItem(itemId);
  }

  /// Reorder items in a set list
  Future<void> reorderSetListItems(int setListId, List<int> itemIds) async {
    for (int i = 0; i < itemIds.length; i++) {
      final items = await getSetListItems(setListId);
      final item = items.cast<SetListItem?>().firstWhere(
            (it) => it?.id == itemIds[i],
            orElse: () => null,
          );

      if (item != null) {
        // Note: We need to add an update method to the database
        // For now, we'll delete and re-insert
        await _database.deleteSetListItem(item.id);
        await _database.insertSetListItem(
          SetListItemsCompanion(
            id: drift.Value(item.id),
            setListId: drift.Value(item.setListId),
            documentId: drift.Value(item.documentId),
            orderIndex: drift.Value(i),
            notes: drift.Value(item.notes),
          ),
        );
      }
    }
  }

  /// Get set lists containing a specific document
  Future<List<SetList>> getSetListsContainingDocument(int documentId) async {
    final allSetLists = await getAllSetLists();
    final result = <SetList>[];

    for (final setList in allSetLists) {
      final items = await getSetListItems(setList.id);
      if (items.any((item) => item.documentId == documentId)) {
        result.add(setList);
      }
    }

    return result;
  }

  /// Update the modified timestamp for a set list
  Future<void> touchSetList(int setListId) async {
    final setList = await getSetList(setListId);
    if (setList != null) {
      final updated = setList.copyWith(modifiedAt: DateTime.now());
      await updateSetList(updated);
    }
  }

  /// Duplicate a set list
  Future<int> duplicateSetList(int setListId) async {
    final originalSetList = await getSetList(setListId);
    if (originalSetList == null) {
      throw Exception('Set list not found');
    }

    // Create new set list
    final newSetListId = await createSetList(
      '${originalSetList.name} (Copy)',
      description: originalSetList.description,
    );

    // Copy items
    final items = await getSetListItems(setListId);
    for (final item in items) {
      await addDocumentToSetList(
        setListId: newSetListId,
        documentId: item.documentId,
        notes: item.notes,
      );
    }

    return newSetListId;
  }
}
