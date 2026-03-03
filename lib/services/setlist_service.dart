import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/database.dart';
import 'database_service.dart';
import 'file_watcher_service.dart';
import 'sync_service.dart';

/// Service to manage set lists
class SetListService {
  final AppDatabase _database = DatabaseService.instance.database;

  void _scheduleSyncWrite(int setListId) {
    if (kIsWeb) return;
    FileWatcherService.instance.getPdfDirectoryPath().then((pdfDir) {
      SyncManager.instance.scheduleSetListWrite(
        db: _database,
        setListId: setListId,
        pdfDirectoryPath: pdfDir,
      );
    });
  }

  /// Get all set lists
  Future<List<SetList>> getAllSetLists() {
    return _database.getAllSetLists();
  }

  /// Get a specific set list
  Future<SetList?> getSetList(int id) {
    return _database.getSetList(id);
  }

  /// Create a new set list
  Future<int> createSetList(String name, {String? description}) async {
    final id = await _database.insertSetList(
      SetListsCompanion(
        name: drift.Value(name),
        description: drift.Value(description),
      ),
    );
    _scheduleSyncWrite(id);
    return id;
  }

  /// Update a set list
  Future<void> updateSetList(SetList setList) async {
    await _database.updateSetList(setList);
    _scheduleSyncWrite(setList.id);
  }

  /// Delete a set list
  Future<void> deleteSetList(int id) async {
    final setList = await getSetList(id);
    await _database.deleteSetList(id);
    if (setList != null && !kIsWeb) {
      final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
      await deleteSetListFileFromDisk(
        setListName: setList.name,
        pdfDirectoryPath: pdfDir,
      );
    }
  }

  /// Get items in a set list
  Future<List<SetListItem>> getSetListItems(int setListId) {
    return _database.getSetListItems(setListId);
  }

  /// Get documents in a set list
  Future<List<Document>> getSetListDocuments(int setListId) {
    return _database.getDocumentsInSetList(setListId);
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

    final itemId = await _database.insertSetListItem(
      SetListItemsCompanion(
        setListId: drift.Value(setListId),
        documentId: drift.Value(documentId),
        orderIndex: drift.Value(orderIndex),
        notes: drift.Value(notes),
      ),
    );
    _scheduleSyncWrite(setListId);
    return itemId;
  }

  /// Remove a document from a set list
  Future<void> removeDocumentFromSetList(int itemId, {int? setListId}) async {
    await _database.deleteSetListItem(itemId);
    if (setListId != null) {
      _scheduleSyncWrite(setListId);
    }
  }

  /// Reorder items in a set list
  Future<void> reorderSetListItems(int setListId, List<int> itemIds) async {
    final items = await getSetListItems(setListId);
    final itemsById = {for (final item in items) item.id: item};

    for (int i = 0; i < itemIds.length; i++) {
      final item = itemsById[itemIds[i]];
      if (item == null) continue;

      // Delete and re-insert with updated order index
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
    _scheduleSyncWrite(setListId);
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
