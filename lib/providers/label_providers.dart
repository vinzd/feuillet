import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../services/label_service.dart';

/// Watches all labels in the database (for the filter bar).
final allLabelsProvider = StreamProvider<List<Label>>((ref) {
  return LabelService.instance.watchAllLabels();
});

/// Watches labels for a specific document.
final documentLabelsProvider =
    StreamProvider.family<List<Label>, int>((ref, documentId) {
  return LabelService.instance.watchLabelsForDocument(documentId);
});
