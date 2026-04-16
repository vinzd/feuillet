import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:watcher/watcher.dart';

import '../models/database.dart';
import 'annotation_service.dart';
import 'file_watcher_service.dart';

const _prettyEncoder = JsonEncoder.withIndent('  ');

/// Given a score file name (e.g., "Bach - Suite 1.pdf"), returns the
/// corresponding sidecar file name ("Bach - Suite 1.feuillet.json").
///
/// Works with both bare file names and full paths.
String sidecarFileName(String scoreFileName) {
  final dir = p.dirname(scoreFileName);
  final baseName = p.basenameWithoutExtension(scoreFileName);
  final sidecar = '$baseName.feuillet.json';
  if (dir == '.' && !scoreFileName.contains(p.separator)) {
    return sidecar;
  }
  return p.join(dir, sidecar);
}

/// Holds the strokes for a single page within a sidecar layer.
class SidecarPageAnnotations {
  final int pageNumber;
  final List<DrawingStroke> strokes;

  SidecarPageAnnotations({required this.pageNumber, required this.strokes});

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };

  factory SidecarPageAnnotations.fromJson(Map<String, dynamic> json) {
    return SidecarPageAnnotations(
      pageNumber: json['pageNumber'] as int,
      strokes: (json['strokes'] as List)
          .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Represents a single annotation layer in a sidecar file.
class SidecarLayer {
  final String name;
  final bool isVisible;
  final int orderIndex;
  final List<SidecarPageAnnotations> annotations;

  SidecarLayer({
    required this.name,
    required this.isVisible,
    required this.orderIndex,
    required this.annotations,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'isVisible': isVisible,
    'orderIndex': orderIndex,
    'annotations': annotations.map((a) => a.toJson()).toList(),
  };

  factory SidecarLayer.fromJson(Map<String, dynamic> json) {
    return SidecarLayer(
      name: json['name'] as String,
      isVisible: json['isVisible'] as bool,
      orderIndex: json['orderIndex'] as int,
      annotations: (json['annotations'] as List)
          .map(
            (a) => SidecarPageAnnotations.fromJson(a as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// A label entry within a sidecar file.
class SidecarLabel {
  final String name;
  final int? color;

  SidecarLabel({required this.name, this.color});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'name': name};
    if (color != null) json['color'] = color;
    return json;
  }

  factory SidecarLabel.fromJson(Map<String, dynamic> json) {
    return SidecarLabel(
      name: json['name'] as String,
      color: json['color'] as int?,
    );
  }
}

/// Top-level sidecar file data model for annotation sync via Syncthing.
class AnnotationSidecar {
  final int version;
  final DateTime modifiedAt;
  final List<SidecarLayer> layers;
  final List<SidecarLabel> labels;

  AnnotationSidecar({
    required this.version,
    required this.modifiedAt,
    required this.layers,
    this.labels = const [],
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'layers': layers.map((l) => l.toJson()).toList(),
    if (labels.isNotEmpty) 'labels': labels.map((l) => l.toJson()).toList(),
  };

  factory AnnotationSidecar.fromJson(Map<String, dynamic> json) {
    return AnnotationSidecar(
      version: json['version'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      layers: (json['layers'] as List)
          .map((l) => SidecarLayer.fromJson(l as Map<String, dynamic>))
          .toList(),
      labels:
          (json['labels'] as List?)
              ?.map((l) => SidecarLabel.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ---------------------------------------------------------------------------
// Database → Sidecar export
// ---------------------------------------------------------------------------

/// Reads annotation layers and strokes for [documentId] from [db] and builds
/// an [AnnotationSidecar] model.
///
/// Returns `null` if the document has no layers/strokes and no labels.
Future<AnnotationSidecar?> buildAnnotationSidecar(
  AppDatabase db,
  int documentId,
) async {
  final layers = await db.getAnnotationLayers(documentId);
  final docLabels = await db.getLabelsForDocument(documentId);

  final sidecarLayers = <SidecarLayer>[];

  for (final layer in layers) {
    // Query all annotations for this layer (across all pages).
    final allAnnotations = await (db.select(
      db.annotations,
    )..where((a) => a.layerId.equals(layer.id))).get();

    if (allAnnotations.isEmpty) continue;

    // Group annotations by page number.
    final byPage = <int, List<DrawingStroke>>{};
    for (final annotation in allAnnotations) {
      final stroke = DrawingStroke.fromJson(
        jsonDecode(annotation.data) as Map<String, dynamic>,
      );
      byPage.putIfAbsent(annotation.pageNumber, () => []).add(stroke);
    }

    // Build sorted page list.
    final sortedPages = byPage.keys.toList()..sort();
    final pageAnnotations = sortedPages
        .map(
          (page) =>
              SidecarPageAnnotations(pageNumber: page, strokes: byPage[page]!),
        )
        .toList();

    sidecarLayers.add(
      SidecarLayer(
        name: layer.name,
        isVisible: layer.isVisible,
        orderIndex: layer.orderIndex,
        annotations: pageAnnotations,
      ),
    );
  }

  if (sidecarLayers.isEmpty && docLabels.isEmpty) return null;

  final sidecarLabels = docLabels
      .map((l) => SidecarLabel(name: l.name, color: l.color))
      .toList();

  return AnnotationSidecar(
    version: sidecarLabels.isNotEmpty ? 2 : 1,
    modifiedAt: DateTime.now().toUtc(),
    layers: sidecarLayers,
    labels: sidecarLabels,
  );
}

// ---------------------------------------------------------------------------
// Sidecar → Database import
// ---------------------------------------------------------------------------

/// Imports an [AnnotationSidecar] into the database for [documentId],
/// replacing all existing annotation layers and their annotations.
Future<void> importAnnotationSidecar(
  AppDatabase db,
  int documentId,
  AnnotationSidecar sidecar,
) async {
  // 1. Delete all existing layers (cascade deletes annotations too).
  final existingLayers = await db.getAnnotationLayers(documentId);
  for (final layer in existingLayers) {
    await db.deleteAnnotationLayer(layer.id);
  }

  // 2. Create new layers and annotations from the sidecar model.
  for (final sidecarLayer in sidecar.layers) {
    final layerId = await db.insertAnnotationLayer(
      AnnotationLayersCompanion(
        documentId: Value(documentId),
        name: Value(sidecarLayer.name),
        orderIndex: Value(sidecarLayer.orderIndex),
        isVisible: Value(sidecarLayer.isVisible),
      ),
    );

    for (final pageAnnotation in sidecarLayer.annotations) {
      for (final stroke in pageAnnotation.strokes) {
        await db.insertAnnotation(
          AnnotationsCompanion(
            layerId: Value(layerId),
            pageNumber: Value(pageAnnotation.pageNumber),
            type: Value(stroke.type.toString()),
            data: Value(jsonEncode(stroke.toJson())),
          ),
        );
      }
    }
  }

  // Import labels
  for (final sidecarLabel in sidecar.labels) {
    final existing = await db.getLabel(sidecarLabel.name);
    if (existing == null) {
      await db.insertLabel(
        LabelsCompanion(
          name: Value(sidecarLabel.name),
          color: Value(sidecarLabel.color),
        ),
      );
    }
    // Don't overwrite existing label color — keep local color
    await db.addLabelToDocument(documentId, sidecarLabel.name);
  }
}

// ---------------------------------------------------------------------------
// Set List file serialization
// ---------------------------------------------------------------------------

/// Characters unsafe for file names on common file systems.
final _unsafeFileNameChars = RegExp(r'[/\\:*?"<>|]');

/// Sanitizes a set list [name] and returns `"<sanitized>.setlist.json"`.
///
/// Removes characters that are unsafe on Windows, macOS, and Linux file
/// systems (`/\:*?"<>|`).
///
/// Example: `"Concert: 12/25"` → `"Concert 1225.setlist.json"`.
String setListFileName(String name) {
  final sanitized = name.replaceAll(_unsafeFileNameChars, '');
  return '$sanitized.setlist.json';
}

// ---------------------------------------------------------------------------
// Database → Set List file export
// ---------------------------------------------------------------------------

/// Returns the portion of [fullPath] relative to [basePath].
///
/// If [fullPath] starts with `basePath/`, the prefix (including the trailing
/// separator) is stripped. Otherwise falls back to `p.basename(fullPath)`.
String _relativePath(String fullPath, String basePath) {
  final prefix = basePath.endsWith('/') ? basePath : '$basePath/';
  if (fullPath.startsWith(prefix)) {
    return fullPath.substring(prefix.length);
  }
  return p.basename(fullPath);
}

/// Reads a set list and its items from [db] and builds a [SetListFile] model,
/// resolving document IDs to relative paths under [pdfDirectoryPath].
///
/// Returns `null` if the set list does not exist.
Future<SetListFile?> buildSetListFile(
  AppDatabase db,
  int setListId,
  String pdfDirectoryPath,
) async {
  final setList = await db.getSetList(setListId);
  if (setList == null) return null;

  final items = await db.getSetListItems(setListId);
  final fileItems = <SetListFileItem>[];

  for (final item in items) {
    final doc = await db.getDocument(item.documentId);
    if (doc == null) continue;

    fileItems.add(
      SetListFileItem(
        documentPath: _relativePath(doc.filePath, pdfDirectoryPath),
        orderIndex: item.orderIndex,
        notes: item.notes,
      ),
    );
  }

  return SetListFile(
    version: 1,
    modifiedAt: setList.modifiedAt,
    name: setList.name,
    description: setList.description,
    items: fileItems,
  );
}

/// A single item (document reference) within a set list file.
class SetListFileItem {
  final String documentPath;
  final int orderIndex;
  final String? notes;

  SetListFileItem({
    required this.documentPath,
    required this.orderIndex,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'documentPath': documentPath,
    'orderIndex': orderIndex,
    'notes': notes,
  };

  factory SetListFileItem.fromJson(Map<String, dynamic> json) {
    return SetListFileItem(
      documentPath: json['documentPath'] as String,
      orderIndex: json['orderIndex'] as int,
      notes: json['notes'] as String?,
    );
  }
}

/// Top-level data model for a `.setlist.json` file synced via Syncthing.
class SetListFile {
  final int version;
  final DateTime modifiedAt;
  final String name;
  final String? description;
  final List<SetListFileItem> items;

  SetListFile({
    required this.version,
    required this.modifiedAt,
    required this.name,
    this.description,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'name': name,
    'description': description,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory SetListFile.fromJson(Map<String, dynamic> json) {
    return SetListFile(
      version: json['version'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      name: json['name'] as String,
      description: json['description'] as String?,
      items: (json['items'] as List)
          .map((i) => SetListFileItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Set List file → Database import
// ---------------------------------------------------------------------------

/// Imports a [SetListFile] into the database, replacing any existing set list
/// with the same name.
///
/// Document references are resolved by prepending [pdfDirectoryPath] to each
/// item's relative `documentPath` and matching against `filePath` in the
/// database. Items whose documents are not found are silently skipped.
///
/// If a set list with the same name already exists, it is updated in-place
/// (preserving its ID) rather than deleted and recreated.
///
/// Returns the set list ID, or `null` on failure.
Future<int?> importSetListFile(
  AppDatabase db,
  SetListFile setListFile,
  String pdfDirectoryPath,
) async {
  try {
    // 1. Find existing set list with the same name, or create a new one.
    final existing = await db.getAllSetLists();
    int? setListId;
    for (final sl in existing) {
      if (sl.name == setListFile.name) {
        // Update in-place to preserve the ID.
        await db.updateSetList(
          sl.copyWith(
            description: Value(setListFile.description),
            modifiedAt: setListFile.modifiedAt,
          ),
        );
        // Remove old items; we'll re-insert from the file.
        await db.deleteSetListItemsBySetListId(sl.id);
        setListId = sl.id;
        break;
      }
    }

    setListId ??= await db.insertSetList(
      SetListsCompanion(
        name: Value(setListFile.name),
        description: Value(setListFile.description),
        modifiedAt: Value(setListFile.modifiedAt),
      ),
    );

    // 2. Resolve each item's document and insert set list items.
    final allDocuments = await db.getAllDocuments();
    final docsByPath = {for (final d in allDocuments) d.filePath: d};
    for (final item in setListFile.items) {
      final fullPath = p.join(pdfDirectoryPath, item.documentPath);
      final matchingDoc = docsByPath[fullPath];
      if (matchingDoc == null) continue;

      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(matchingDoc.id),
          orderIndex: Value(item.orderIndex),
          notes: Value(item.notes),
        ),
      );
    }

    return setListId;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// File I/O – Annotation sidecars
// ---------------------------------------------------------------------------

/// Writes the annotation sidecar for [documentId] to disk next to
/// [scoreFilePath].
///
/// If the document has no annotations the sidecar file is deleted (if it
/// exists). Otherwise the sidecar is serialised to pretty JSON and written
/// atomically (write to `.tmp`, then rename).
Future<void> writeAnnotationSidecarToDisk({
  required AppDatabase db,
  required int documentId,
  required String scoreFilePath,
}) async {
  final sidecarPath = sidecarFileName(scoreFilePath);
  final sidecar = await buildAnnotationSidecar(db, documentId);

  if (sidecar == null) {
    final file = File(sidecarPath);
    if (await file.exists()) {
      await file.delete();
    }
    return;
  }

  final jsonStr = _prettyEncoder.convert(sidecar.toJson());
  final tmpPath = '$sidecarPath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(jsonStr);
  await tmpFile.rename(sidecarPath);
}

/// Reads and parses an [AnnotationSidecar] from the sidecar file adjacent to
/// [scoreFilePath].
///
/// Returns `null` if the file does not exist or cannot be parsed.
Future<AnnotationSidecar?> readAnnotationSidecarFromDisk(
  String scoreFilePath,
) async {
  try {
    final sidecarPath = sidecarFileName(scoreFilePath);
    final file = File(sidecarPath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return AnnotationSidecar.fromJson(json);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// File I/O – Set list files
// ---------------------------------------------------------------------------

/// Writes the set list identified by [setListId] to disk as
/// `<pdfDirectoryPath>/setlists/<sanitized-name>.setlist.json`.
///
/// Creates the `setlists/` subdirectory if it does not exist. The file is
/// written atomically (write to `.tmp`, then rename).
Future<void> writeSetListFileToDisk({
  required AppDatabase db,
  required int setListId,
  required String pdfDirectoryPath,
}) async {
  final setListFile = await buildSetListFile(db, setListId, pdfDirectoryPath);
  if (setListFile == null) return;

  final setListsDir = Directory(p.join(pdfDirectoryPath, 'setlists'));
  if (!await setListsDir.exists()) {
    await setListsDir.create(recursive: true);
  }

  final fileName = setListFileName(setListFile.name);
  final filePath = p.join(setListsDir.path, fileName);
  final jsonStr = _prettyEncoder.convert(setListFile.toJson());

  final tmpPath = '$filePath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(jsonStr);
  await tmpFile.rename(filePath);
}

/// Reads and parses a [SetListFile] from [filePath].
///
/// Returns `null` if the file does not exist or cannot be parsed.
Future<SetListFile?> readSetListFileFromDisk(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return SetListFile.fromJson(json);
  } catch (_) {
    return null;
  }
}

/// Deletes the set list file for [setListName] from
/// `<pdfDirectoryPath>/setlists/`.
///
/// Does nothing if the file does not exist.
Future<void> deleteSetListFileFromDisk({
  required String setListName,
  required String pdfDirectoryPath,
}) async {
  final fileName = setListFileName(setListName);
  final filePath = p.join(pdfDirectoryPath, 'setlists', fileName);
  final file = File(filePath);
  if (await file.exists()) {
    await file.delete();
  }
}

// ---------------------------------------------------------------------------
// SyncManager — orchestration and loop suppression
// ---------------------------------------------------------------------------

/// Orchestrates annotation and set list sync: debounces writes, suppresses
/// file-watcher loops, handles incoming sidecar/set-list changes, and performs
/// startup reconciliation.
class SyncManager {
  SyncManager._();

  // Singleton
  static SyncManager? _instance;
  static SyncManager get instance => _instance ??= SyncManager._();
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  // State
  final Map<String, DateTime> _suppressedPaths = {};
  final Map<int, Timer> _annotationDebounceTimers = {};
  final Map<int, Timer> _setListDebounceTimers = {};
  final Map<String, Timer> _incomingDebounceTimers = {};
  StreamSubscription<dynamic>? _syncChangesSubscription;

  static const _suppressionDuration = Duration(seconds: 2);
  static const _debounceDuration = Duration(seconds: 2);

  // ---------------------------------------------------------------------------
  // Suppression
  // ---------------------------------------------------------------------------

  /// Marks [path] as suppressed so incoming file-watcher events for it are
  /// ignored for [_suppressionDuration].
  void suppressPath(String path) {
    suppressPathWithDuration(path, _suppressionDuration);
  }

  /// Marks [path] as suppressed for [duration]. Visible for testing.
  @visibleForTesting
  void suppressPathWithDuration(String path, Duration duration) {
    _suppressedPaths[path] = DateTime.now().add(duration);
  }

  /// Returns `true` if [path] is currently suppressed.
  ///
  /// Expired entries are removed lazily.
  bool isSuppressed(String path) {
    final expiry = _suppressedPaths[path];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _suppressedPaths.remove(path);
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Debounced writes
  // ---------------------------------------------------------------------------

  /// Schedules a debounced write of the annotation sidecar for [documentId].
  ///
  /// If a previous timer for the same document is pending it is cancelled.
  /// After [_debounceDuration] the sidecar is written and the output path is
  /// suppressed so the file watcher does not re-import it.
  void scheduleAnnotationWrite({
    required AppDatabase db,
    required int documentId,
    required String scoreFilePath,
  }) {
    _annotationDebounceTimers[documentId]?.cancel();
    _annotationDebounceTimers[documentId] = Timer(_debounceDuration, () async {
      try {
        await writeAnnotationSidecarToDisk(
          db: db,
          documentId: documentId,
          scoreFilePath: scoreFilePath,
        );
        suppressPath(sidecarFileName(scoreFilePath));
      } catch (e) {
        debugPrint('SyncManager: failed to write annotation sidecar: $e');
      }
    });
  }

  /// Schedules a debounced write of the set list file for [setListId].
  ///
  /// If a previous timer for the same set list is pending it is cancelled.
  /// After [_debounceDuration] the file is written and the output path is
  /// suppressed so the file watcher does not re-import it.
  void scheduleSetListWrite({
    required AppDatabase db,
    required int setListId,
    required String pdfDirectoryPath,
  }) {
    _setListDebounceTimers[setListId]?.cancel();
    _setListDebounceTimers[setListId] = Timer(_debounceDuration, () async {
      try {
        await writeSetListFileToDisk(
          db: db,
          setListId: setListId,
          pdfDirectoryPath: pdfDirectoryPath,
        );
        // Suppress the written file path.
        final setList = await db.getSetList(setListId);
        if (setList != null) {
          final fileName = setListFileName(setList.name);
          final filePath = p.join(pdfDirectoryPath, 'setlists', fileName);
          suppressPath(filePath);
        }
      } catch (e) {
        debugPrint('SyncManager: failed to write set list file: $e');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Incoming changes listener
  // ---------------------------------------------------------------------------

  /// Subscribes to [syncChanges] and processes incoming sidecar / set list
  /// file events, skipping any that are currently suppressed.
  void startListening({
    required Stream<dynamic> syncChanges,
    required AppDatabase db,
    required Future<String> Function() getPdfDirectoryPath,
  }) {
    _syncChangesSubscription?.cancel();
    _syncChangesSubscription = syncChanges.listen((event) async {
      try {
        final String filePath;
        if (event is WatchEvent) {
          filePath = event.path;
        } else {
          return;
        }

        if (isSuppressed(filePath)) {
          debugPrint('SyncManager: suppressed event for $filePath');
          return;
        }

        // Debounce incoming events — file watchers often emit multiple
        // events (create, modify, …) for a single Syncthing sync.
        _incomingDebounceTimers[filePath]?.cancel();
        _incomingDebounceTimers[filePath] = Timer(
          const Duration(milliseconds: 500),
          () async {
            _incomingDebounceTimers.remove(filePath);
            try {
              if (FileWatcherService.isSidecarFile(filePath)) {
                await _handleIncomingSidecar(filePath, db);
              } else if (FileWatcherService.isSetListFile(filePath)) {
                final pdfDir = await getPdfDirectoryPath();
                await _handleIncomingSetList(filePath, db, pdfDir);
              }
            } catch (e) {
              debugPrint('SyncManager: error handling sync event: $e');
            }
          },
        );
      } catch (e) {
        debugPrint('SyncManager: error handling sync event: $e');
      }
    });
  }

  Future<void> _handleIncomingSidecar(
    String sidecarPath,
    AppDatabase db,
  ) async {
    // Derive score file path: remove ".feuillet.json" suffix.
    // e.g., "/docs/Bach - Suite 1.feuillet.json" → "/docs/Bach - Suite 1"
    final withoutSuffix = sidecarPath.replaceAll('.feuillet.json', '');

    // Find matching document by path prefix.
    final allDocs = await db.getAllDocuments();
    final matchingDoc = allDocs
        .where((d) => p.withoutExtension(d.filePath) == withoutSuffix)
        .firstOrNull;

    if (matchingDoc == null) {
      debugPrint('SyncManager: no matching document for sidecar $sidecarPath');
      return;
    }

    final sidecarFile = File(sidecarPath);
    if (!await sidecarFile.exists()) return;
    AnnotationSidecar sidecar;
    try {
      final content = await sidecarFile.readAsString();
      sidecar = AnnotationSidecar.fromJson(jsonDecode(content));
    } catch (e) {
      debugPrint('SyncManager: error reading sidecar $sidecarPath: $e');
      return;
    }

    await importAnnotationSidecar(db, matchingDoc.id, sidecar);
    debugPrint('SyncManager: imported sidecar for ${matchingDoc.name}');
  }

  Future<void> _handleIncomingSetList(
    String filePath,
    AppDatabase db,
    String pdfDirectoryPath,
  ) async {
    final setListFile = await readSetListFileFromDisk(filePath);
    if (setListFile == null) return;

    await importSetListFile(db, setListFile, pdfDirectoryPath);
    debugPrint('SyncManager: imported set list ${setListFile.name}');
  }

  // ---------------------------------------------------------------------------
  // Startup reconciliation
  // ---------------------------------------------------------------------------

  /// Performs a full reconciliation on startup:
  ///
  /// 1. For each document in DB (skipping `web://` paths), imports the sidecar
  ///    from disk if it exists.
  /// 2. Scans the `setlists/` directory for `.setlist.json` files and imports
  ///    each one.
  /// 3. For documents that have annotations in DB but no sidecar on disk,
  ///    exports the sidecar.
  Future<void> reconcileOnStartup({
    required AppDatabase db,
    required String pdfDirectoryPath,
  }) async {
    debugPrint('SyncManager: starting reconciliation');

    final allDocs = await db.getAllDocuments();

    // 1. Import sidecars from disk.
    for (final doc in allDocs) {
      if (doc.filePath.startsWith('web://')) continue;

      try {
        final sidecar = await readAnnotationSidecarFromDisk(doc.filePath);
        if (sidecar != null) {
          // Compare timestamps: only import if sidecar is newer than DB
          final latestDbModified = await _latestAnnotationModifiedAt(
            db,
            doc.id,
          );
          if (latestDbModified == null ||
              sidecar.modifiedAt.isAfter(latestDbModified)) {
            await importAnnotationSidecar(db, doc.id, sidecar);
            debugPrint('SyncManager: reconciled sidecar for ${doc.name}');
          }
        }
      } catch (e) {
        debugPrint('SyncManager: error importing sidecar for ${doc.name}: $e');
      }
    }

    // 2. Scan setlists/ directory.
    final setListsDir = Directory(p.join(pdfDirectoryPath, 'setlists'));
    if (await setListsDir.exists()) {
      await for (final entity in setListsDir.list()) {
        if (entity is File && FileWatcherService.isSetListFile(entity.path)) {
          try {
            final setListFile = await readSetListFileFromDisk(entity.path);
            if (setListFile != null) {
              await importSetListFile(db, setListFile, pdfDirectoryPath);
              debugPrint(
                'SyncManager: reconciled set list ${setListFile.name}',
              );
            }
          } catch (e) {
            debugPrint(
              'SyncManager: error importing set list ${entity.path}: $e',
            );
          }
        }
      }
    }

    // 3. Export annotations that exist in DB but have no sidecar on disk.
    for (final doc in allDocs) {
      if (doc.filePath.startsWith('web://')) continue;

      try {
        final sidecarPath = sidecarFileName(doc.filePath);
        final sidecarExists = await File(sidecarPath).exists();
        if (!sidecarExists) {
          // Check if DB has annotations for this document.
          final layers = await db.getAnnotationLayers(doc.id);
          if (layers.isNotEmpty) {
            await writeAnnotationSidecarToDisk(
              db: db,
              documentId: doc.id,
              scoreFilePath: doc.filePath,
            );
            debugPrint('SyncManager: exported sidecar for ${doc.name}');
          }
        }
      } catch (e) {
        debugPrint('SyncManager: error exporting sidecar for ${doc.name}: $e');
      }
    }

    debugPrint('SyncManager: reconciliation complete');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Get the most recent annotation modifiedAt timestamp for a document.
  /// Returns null if the document has no annotations.
  Future<DateTime?> _latestAnnotationModifiedAt(
    AppDatabase db,
    int documentId,
  ) async {
    final layers = await db.getAnnotationLayers(documentId);
    if (layers.isEmpty) return null;

    DateTime? latest;
    for (final layer in layers) {
      final annotations =
          await (db.select(db.annotations)
                ..where((a) => a.layerId.equals(layer.id))
                ..orderBy([(a) => OrderingTerm.desc(a.modifiedAt)])
                ..limit(1))
              .get();
      if (annotations.isNotEmpty) {
        final mod = annotations.first.modifiedAt;
        if (latest == null || mod.isAfter(latest)) {
          latest = mod;
        }
      }
    }
    return latest;
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Cancels all pending timers and subscriptions.
  void dispose() {
    _syncChangesSubscription?.cancel();
    _syncChangesSubscription = null;

    for (final timer in _annotationDebounceTimers.values) {
      timer.cancel();
    }
    _annotationDebounceTimers.clear();

    for (final timer in _setListDebounceTimers.values) {
      timer.cancel();
    }
    _setListDebounceTimers.clear();

    for (final timer in _incomingDebounceTimers.values) {
      timer.cancel();
    }
    _incomingDebounceTimers.clear();

    _suppressedPaths.clear();
  }
}
