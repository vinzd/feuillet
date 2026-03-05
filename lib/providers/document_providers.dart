import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../services/database_service.dart';

/// Watches all documents in the database.
final documentsProvider = StreamProvider<List<Document>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchAllDocuments();
});

/// Fetches a single document by ID (for URL-based navigation).
final documentByIdProvider = FutureProvider.family<Document?, int>((
  ref,
  id,
) async {
  final db = ref.read(databaseProvider);
  return db.getDocument(id);
});
