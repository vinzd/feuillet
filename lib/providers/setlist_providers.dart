import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../services/database_service.dart';
import '../services/setlist_service.dart';

/// Watches all set lists in the database.
final setListsProvider = StreamProvider<List<SetList>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchAllSetLists();
});

/// Fetches a setlist with its documents and items by ID (for URL-based navigation).
final setListWithDocumentsProvider =
    FutureProvider.family<
      ({SetList? setList, List<Document> documents, List<SetListItem> items}),
      int
    >((ref, id) async {
      final setListService = SetListService.instance;
      final setList = await setListService.getSetList(id);
      final documents = await setListService.getSetListDocuments(id);
      final items = await setListService.getSetListItems(id);
      return (setList: setList, documents: documents, items: items);
    });
