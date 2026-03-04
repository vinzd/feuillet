import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/database.dart';
import 'database_service.dart';
import 'sync_service.dart';

/// Preset label colors, cycled through automatically when creating labels.
const _labelPalette = [
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.amber,
  Colors.orange,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.cyan,
  Colors.lime,
];

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
      final assignedColor = color ?? await _nextColor();
      await _database.insertLabel(
        LabelsCompanion(name: Value(name), color: Value(assignedColor)),
      );
    } catch (_) {
      // Label already exists, ignore
    }
  }

  /// Picks the next color from the palette based on how many labels exist.
  Future<int> _nextColor() async {
    final count = (await _database.getAllLabels()).length;
    return _labelPalette[count % _labelPalette.length].toARGB32();
  }

  Future<void> deleteLabel(String name) => _database.deleteLabel(name);

  Future<void> updateLabelColor(String name, int? color) =>
      _database.updateLabelColor(name, color);

  Future<void> renameLabel(String oldName, String newName) =>
      _database.renameLabel(oldName, newName);

  // Associations

  Future<void> addLabelToDocument(int documentId, String labelName) async {
    await _database.addLabelToDocument(documentId, labelName);
    await _scheduleSidecarWrite(documentId);
  }

  Future<void> removeLabelFromDocument(int documentId, String labelName) async {
    await _database.removeLabelFromDocument(documentId, labelName);
    await _scheduleSidecarWrite(documentId);
  }

  Future<void> addLabelToDocuments(
    List<int> documentIds,
    String labelName,
  ) async {
    for (final docId in documentIds) {
      await _database.addLabelToDocument(docId, labelName);
      await _scheduleSidecarWrite(docId);
    }
  }

  Future<void> _scheduleSidecarWrite(int documentId) async {
    final doc = await _database.getDocument(documentId);
    if (doc == null || doc.filePath.startsWith('web://')) return;

    SyncManager.instance.scheduleAnnotationWrite(
      db: _database,
      documentId: documentId,
      scoreFilePath: doc.filePath,
    );
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
      // Call database directly to avoid triggering sidecar writes during scan
      await _database.addLabelToDocument(documentId, segment);
    }
  }
}
