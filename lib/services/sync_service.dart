import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../models/database.dart';
import 'annotation_service.dart';

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

/// Top-level sidecar file data model for annotation sync via Syncthing.
class AnnotationSidecar {
  final int version;
  final DateTime modifiedAt;
  final List<SidecarLayer> layers;

  AnnotationSidecar({
    required this.version,
    required this.modifiedAt,
    required this.layers,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'layers': layers.map((l) => l.toJson()).toList(),
  };

  factory AnnotationSidecar.fromJson(Map<String, dynamic> json) {
    return AnnotationSidecar(
      version: json['version'] as int,
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      layers: (json['layers'] as List)
          .map((l) => SidecarLayer.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Database → Sidecar export
// ---------------------------------------------------------------------------

/// Reads annotation layers and strokes for [documentId] from [db] and builds
/// an [AnnotationSidecar] model.
///
/// Returns `null` if the document has no layers or no annotation strokes.
Future<AnnotationSidecar?> buildAnnotationSidecar(
  AppDatabase db,
  int documentId,
) async {
  final layers = await db.getAnnotationLayers(documentId);
  if (layers.isEmpty) return null;

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

  if (sidecarLayers.isEmpty) return null;

  return AnnotationSidecar(
    version: 1,
    modifiedAt: DateTime.now().toUtc(),
    layers: sidecarLayers,
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
/// Returns the new set list ID, or `null` on failure.
Future<int?> importSetListFile(
  AppDatabase db,
  SetListFile setListFile,
  String pdfDirectoryPath,
) async {
  try {
    // 1. Delete existing set lists with the same name (replace semantics).
    final existing = await db.getAllSetLists();
    for (final sl in existing) {
      if (sl.name == setListFile.name) {
        await db.deleteSetList(sl.id);
      }
    }

    // 2. Create the new set list.
    final setListId = await db.insertSetList(
      SetListsCompanion(
        name: Value(setListFile.name),
        description: Value(setListFile.description),
        modifiedAt: Value(setListFile.modifiedAt),
      ),
    );

    // 3. Resolve each item's document and insert set list items.
    final allDocuments = await db.getAllDocuments();
    for (final item in setListFile.items) {
      final fullPath = p.join(pdfDirectoryPath, item.documentPath);
      final matchingDoc = allDocuments.cast<Document?>().firstWhere(
        (d) => d!.filePath == fullPath,
        orElse: () => null,
      );
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
