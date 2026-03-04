import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../models/database.dart';
import 'database_service.dart';

class LabelService {
  LabelService._() : _database = DatabaseService.instance.database;

  /// Constructor for testing with a custom database instance.
  LabelService.forTesting(this._database);

  static LabelService? _instance;
  static LabelService get instance => _instance ??= LabelService._();

  static void resetInstance() {
    _instance = null;
  }

  final AppDatabase _database;

  // CRUD

  Future<void> createLabel(String name, {int? color}) async {
    try {
      await _database.insertLabel(
        LabelsCompanion(name: Value(name), color: Value(color)),
      );
    } catch (_) {
      // Label already exists, ignore
    }
  }

  Future<void> deleteLabel(String name) => _database.deleteLabel(name);

  Future<void> updateLabelColor(String name, int? color) =>
      _database.updateLabelColor(name, color);

  Future<void> renameLabel(String oldName, String newName) =>
      _database.renameLabel(oldName, newName);

  // Associations

  Future<void> addLabelToDocument(int documentId, String labelName) =>
      _database.addLabelToDocument(documentId, labelName);

  Future<void> removeLabelFromDocument(int documentId, String labelName) =>
      _database.removeLabelFromDocument(documentId, labelName);

  Future<void> addLabelToDocuments(
    List<int> documentIds,
    String labelName,
  ) async {
    for (final docId in documentIds) {
      await _database.addLabelToDocument(docId, labelName);
    }
  }

  // Queries

  Future<List<Label>> getAllLabels() => _database.getAllLabels();

  Stream<List<Label>> watchAllLabels() => _database.watchAllLabels();

  Future<List<Label>> getLabelsForDocument(int documentId) =>
      _database.getLabelsForDocument(documentId);

  Stream<List<Label>> watchLabelsForDocument(int documentId) =>
      _database.watchLabelsForDocument(documentId);

  Future<List<int>> getDocumentIdsWithAllLabels(List<String> labelNames) =>
      _database.getDocumentIdsWithAllLabels(labelNames);

  // Auto-labeling from directory path

  Future<void> ensureLabelsFromPath(
    int documentId,
    String filePath,
    String pdfDirectoryPath,
  ) async {
    final prefix = pdfDirectoryPath.endsWith('/')
        ? pdfDirectoryPath
        : '$pdfDirectoryPath/';
    if (!filePath.startsWith(prefix)) return;

    final relativePath = filePath.substring(prefix.length);
    final segments = p.split(p.dirname(relativePath));

    if (segments.length == 1 && segments.first == '.') return;

    for (final segment in segments) {
      if (segment == '.' || segment.isEmpty) continue;
      await createLabel(segment);
      await addLabelToDocument(documentId, segment);
    }
  }
}
