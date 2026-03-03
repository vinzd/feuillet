# Sync Annotations & Set Lists Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sync annotations and set lists across devices via Syncthing using sidecar JSON files alongside score files.

**Architecture:** A new `SyncService` orchestrates reading/writing `.feuillet.json` sidecar files (annotations) and `.setlist.json` files (set lists) in the Syncthing-watched document directory. The existing `FileWatcherService` is extended to detect incoming sidecar changes. All file I/O goes through `FileAccessService` for Android SAF compatibility.

**Tech Stack:** Flutter/Dart, Drift (SQLite), existing FileAccessService, path package

---

### Task 1: Annotation Sidecar Serialization

Create the core serialization logic for reading/writing `.feuillet.json` files.

**Files:**
- Create: `lib/services/sync_service.dart`
- Create: `test/services/sync_service_test.dart`

**Step 1: Write failing tests for sidecar serialization**

```dart
// test/services/sync_service_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/sync_service.dart';
import 'package:feuillet/services/annotation_service.dart';

void main() {
  group('AnnotationSidecar', () {
    test('toJson produces valid sidecar format', () {
      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3, 14, 30),
        layers: [
          SidecarLayer(
            name: 'Main',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 0,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(10, 20)],
                    color: Colors.red,
                    thickness: 3.0,
                    type: AnnotationType.pen,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final json = sidecar.toJson();
      expect(json['version'], 1);
      expect(json['modifiedAt'], '2026-03-03T14:30:00.000Z');
      expect(json['layers'], isList);
      expect(json['layers'][0]['name'], 'Main');
      expect(json['layers'][0]['isVisible'], true);
      expect(json['layers'][0]['annotations'][0]['pageNumber'], 0);
      expect(json['layers'][0]['annotations'][0]['strokes'], isList);
    });

    test('fromJson roundtrips correctly', () {
      final original = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3, 14, 30),
        layers: [
          SidecarLayer(
            name: 'Layer 1',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 0,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(10, 20), const Offset(30, 40)],
                    color: Colors.blue,
                    thickness: 5.0,
                    type: AnnotationType.highlighter,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final jsonStr = jsonEncode(original.toJson());
      final restored = AnnotationSidecar.fromJson(jsonDecode(jsonStr));

      expect(restored.version, 1);
      expect(restored.modifiedAt, original.modifiedAt);
      expect(restored.layers.length, 1);
      expect(restored.layers[0].name, 'Layer 1');
      expect(restored.layers[0].annotations[0].strokes.length, 1);
      expect(
        restored.layers[0].annotations[0].strokes[0].color.toARGB32(),
        Colors.blue.toARGB32(),
      );
    });

    test('fromJson handles empty layers', () {
      final json = {
        'version': 1,
        'modifiedAt': '2026-03-03T14:30:00.000Z',
        'layers': [],
      };
      final sidecar = AnnotationSidecar.fromJson(json);
      expect(sidecar.layers, isEmpty);
    });
  });

  group('sidecarFileName', () {
    test('produces correct name for PDF', () {
      expect(sidecarFileName('Bach - Suite 1.pdf'), 'Bach - Suite 1.feuillet.json');
    });

    test('produces correct name for image', () {
      expect(sidecarFileName('photo.jpg'), 'photo.feuillet.json');
    });

    test('handles files with multiple dots', () {
      expect(sidecarFileName('J.S. Bach - Suite.pdf'), 'J.S. Bach - Suite.feuillet.json');
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_service_test.dart`
Expected: FAIL — sync_service.dart doesn't exist

**Step 3: Implement sidecar data classes**

```dart
// lib/services/sync_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'annotation_service.dart';

/// File name for a sidecar given a score file name.
String sidecarFileName(String scoreFileName) {
  final withoutExt = p.basenameWithoutExtension(scoreFileName);
  return '$withoutExt.feuillet.json';
}

/// Annotations for one page within a sidecar.
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

/// A layer within a sidecar file.
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
          .map((a) => SidecarPageAnnotations.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Top-level sidecar file model.
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
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_test.dart
git commit -m "feat: add annotation sidecar serialization for Syncthing sync"
```

---

### Task 2: Set List File Serialization

Add serialization for `.setlist.json` files.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Modify: `test/services/sync_service_test.dart`

**Step 1: Write failing tests for set list serialization**

Add to `test/services/sync_service_test.dart`:

```dart
group('SetListFile', () {
  test('toJson produces valid set list format', () {
    final setListFile = SetListFile(
      version: 1,
      modifiedAt: DateTime.utc(2026, 3, 3, 14, 30),
      name: 'Concert Dec 2026',
      description: 'Winter recital',
      items: [
        SetListFileItem(
          documentPath: 'Bach - Cello Suite 1.pdf',
          orderIndex: 0,
          notes: 'No repeat',
        ),
      ],
    );

    final json = setListFile.toJson();
    expect(json['version'], 1);
    expect(json['name'], 'Concert Dec 2026');
    expect(json['description'], 'Winter recital');
    expect(json['items'][0]['documentPath'], 'Bach - Cello Suite 1.pdf');
    expect(json['items'][0]['notes'], 'No repeat');
  });

  test('fromJson roundtrips correctly', () {
    final original = SetListFile(
      version: 1,
      modifiedAt: DateTime.utc(2026, 3, 3),
      name: 'Practice',
      description: null,
      items: [
        SetListFileItem(
          documentPath: 'subfolder/piece.png',
          orderIndex: 0,
          notes: null,
        ),
      ],
    );

    final jsonStr = jsonEncode(original.toJson());
    final restored = SetListFile.fromJson(jsonDecode(jsonStr));

    expect(restored.name, 'Practice');
    expect(restored.description, isNull);
    expect(restored.items[0].documentPath, 'subfolder/piece.png');
    expect(restored.items[0].notes, isNull);
  });
});

group('setListFileName', () {
  test('sanitizes name for file system', () {
    expect(setListFileName('My Set List'), 'My Set List.setlist.json');
  });

  test('strips unsafe characters', () {
    expect(setListFileName('Concert: 12/25'), 'Concert 1225.setlist.json');
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_service_test.dart`
Expected: FAIL — SetListFile not defined

**Step 3: Implement set list data classes**

Add to `lib/services/sync_service.dart`:

```dart
/// Sanitize a set list name for use as a file name.
String setListFileName(String name) {
  // Remove characters unsafe for file systems
  final sanitized = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '');
  return '$sanitized.setlist.json';
}

/// An item in a set list file.
class SetListFileItem {
  final String documentPath; // relative to document directory
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

/// Top-level set list file model.
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
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_test.dart
git commit -m "feat: add set list file serialization for Syncthing sync"
```

---

### Task 3: Export Annotations to Sidecar Files

Add methods to `SyncService` that read annotations from the database and write `.feuillet.json` files to disk.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Create: `test/services/sync_service_export_test.dart`

**Step 1: Write failing tests for annotation export**

```dart
// test/services/sync_service_export_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('exportAnnotationSidecar', () {
    test('builds sidecar from database layers and annotations', () async {
      // Insert a document
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Test.pdf'),
        filePath: const Value('/pdfs/Test.pdf'),
        lastModified: Value(DateTime.utc(2026, 3, 3)),
        fileSize: const Value(1000),
        pageCount: const Value(2),
      ));

      // Insert a layer
      final layerId = await db.insertAnnotationLayer(AnnotationLayersCompanion(
        documentId: Value(docId),
        name: const Value('Main'),
        orderIndex: const Value(0),
        isVisible: const Value(true),
      ));

      // Insert an annotation
      final stroke = DrawingStroke(
        points: [const Offset(10, 20)],
        color: Colors.red,
        thickness: 3.0,
        type: AnnotationType.pen,
      );
      await db.insertAnnotation(AnnotationsCompanion(
        layerId: Value(layerId),
        pageNumber: const Value(0),
        type: const Value('pen'),
        data: Value(jsonEncode(stroke.toJson())),
      ));

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNotNull);
      expect(sidecar!.layers.length, 1);
      expect(sidecar.layers[0].name, 'Main');
      expect(sidecar.layers[0].annotations.length, 1);
      expect(sidecar.layers[0].annotations[0].pageNumber, 0);
      expect(sidecar.layers[0].annotations[0].strokes.length, 1);
    });

    test('returns null when document has no annotations', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Empty.pdf'),
        filePath: const Value('/pdfs/Empty.pdf'),
        lastModified: Value(DateTime.utc(2026, 3, 3)),
        fileSize: const Value(1000),
        pageCount: const Value(1),
      ));

      final sidecar = await buildAnnotationSidecar(db, docId);
      expect(sidecar, isNull);
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_service_export_test.dart`
Expected: FAIL — `buildAnnotationSidecar` not defined

**Step 3: Implement buildAnnotationSidecar**

Add to `lib/services/sync_service.dart`:

```dart
import '../models/database.dart';
import 'database_service.dart';

/// Build an AnnotationSidecar from the database for a given document.
/// Returns null if the document has no annotations.
Future<AnnotationSidecar?> buildAnnotationSidecar(
  AppDatabase db,
  int documentId,
) async {
  final layers = await db.getAnnotationLayers(documentId);
  if (layers.isEmpty) return null;

  final sidecarLayers = <SidecarLayer>[];
  var hasAnyStrokes = false;

  for (final layer in layers) {
    final pageAnnotations = <SidecarPageAnnotations>[];

    // We need to get all annotations for this layer across all pages.
    // Query each page's annotations. Since we don't know the page count,
    // query all annotations for this layer.
    final allAnnotations = await (db.select(db.annotations)
          ..where((a) => a.layerId.equals(layer.id))
          ..orderBy([(a) => OrderingTerm.asc(a.pageNumber)]))
        .get();

    // Group by page number
    final byPage = <int, List<DrawingStroke>>{};
    for (final annotation in allAnnotations) {
      try {
        final data = jsonDecode(annotation.data) as Map<String, dynamic>;
        final stroke = DrawingStroke.fromJson(data);
        byPage.putIfAbsent(annotation.pageNumber, () => []).add(stroke);
      } catch (e) {
        debugPrint('SyncService: Error decoding annotation: $e');
      }
    }

    for (final entry in byPage.entries) {
      hasAnyStrokes = true;
      pageAnnotations.add(SidecarPageAnnotations(
        pageNumber: entry.key,
        strokes: entry.value,
      ));
    }

    sidecarLayers.add(SidecarLayer(
      name: layer.name,
      isVisible: layer.isVisible,
      orderIndex: layer.orderIndex,
      annotations: pageAnnotations,
    ));
  }

  if (!hasAnyStrokes) return null;

  return AnnotationSidecar(
    version: 1,
    modifiedAt: DateTime.now().toUtc(),
    layers: sidecarLayers,
  );
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_service_export_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_export_test.dart
git commit -m "feat: build annotation sidecars from database"
```

---

### Task 4: Export Set Lists to Files

Add a function to build a `SetListFile` from the database, resolving document IDs to relative paths.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Modify: `test/services/sync_service_export_test.dart`

**Step 1: Write failing tests**

Add to `test/services/sync_service_export_test.dart`:

```dart
group('buildSetListFile', () {
  test('builds set list file with relative document paths', () async {
    final docId = await db.insertDocument(DocumentsCompanion(
      name: const Value('Bach.pdf'),
      filePath: const Value('/music/pdfs/Bach.pdf'),
      lastModified: Value(DateTime.utc(2026, 3, 3)),
      fileSize: const Value(1000),
      pageCount: const Value(5),
    ));

    final setListId = await db.insertSetList(SetListsCompanion(
      name: const Value('Concert'),
      description: const Value('Winter recital'),
    ));

    await db.insertSetListItem(SetListItemsCompanion(
      setListId: Value(setListId),
      documentId: Value(docId),
      orderIndex: const Value(0),
      notes: const Value('Open with this'),
    ));

    final setListFile = await buildSetListFile(
      db,
      setListId,
      '/music/pdfs',
    );

    expect(setListFile, isNotNull);
    expect(setListFile!.name, 'Concert');
    expect(setListFile.description, 'Winter recital');
    expect(setListFile.items.length, 1);
    expect(setListFile.items[0].documentPath, 'Bach.pdf');
    expect(setListFile.items[0].notes, 'Open with this');
  });

  test('handles subdirectory paths correctly', () async {
    final docId = await db.insertDocument(DocumentsCompanion(
      name: const Value('Piece.png'),
      filePath: const Value('/music/pdfs/subfolder/Piece.png'),
      lastModified: Value(DateTime.utc(2026, 3, 3)),
      fileSize: const Value(500),
      pageCount: const Value(1),
      documentType: const Value('image'),
    ));

    final setListId = await db.insertSetList(SetListsCompanion(
      name: const Value('Practice'),
    ));

    await db.insertSetListItem(SetListItemsCompanion(
      setListId: Value(setListId),
      documentId: Value(docId),
      orderIndex: const Value(0),
    ));

    final setListFile = await buildSetListFile(db, setListId, '/music/pdfs');
    expect(setListFile!.items[0].documentPath, 'subfolder/Piece.png');
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_service_export_test.dart`
Expected: FAIL — `buildSetListFile` not defined

**Step 3: Implement buildSetListFile**

Add to `lib/services/sync_service.dart`:

```dart
/// Build a SetListFile from the database for a given set list.
/// [pdfDirectoryPath] is the root document directory, used to compute relative paths.
/// Returns null if the set list doesn't exist.
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

    // Compute relative path from document directory
    final relativePath = _relativePath(doc.filePath, pdfDirectoryPath);

    fileItems.add(SetListFileItem(
      documentPath: relativePath,
      orderIndex: item.orderIndex,
      notes: item.notes,
    ));
  }

  return SetListFile(
    version: 1,
    modifiedAt: setList.modifiedAt.toUtc(),
    name: setList.name,
    description: setList.description,
    items: fileItems,
  );
}

/// Compute a relative path from [fullPath] relative to [basePath].
String _relativePath(String fullPath, String basePath) {
  final normalized = basePath.endsWith('/') ? basePath : '$basePath/';
  if (fullPath.startsWith(normalized)) {
    return fullPath.substring(normalized.length);
  }
  return p.basename(fullPath);
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_service_export_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_export_test.dart
git commit -m "feat: build set list files from database with relative paths"
```

---

### Task 5: Import Annotations from Sidecar Files

Add a function to import a sidecar file into the database, replacing existing annotations for that document.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Create: `test/services/sync_service_import_test.dart`

**Step 1: Write failing tests**

```dart
// test/services/sync_service_import_test.dart
import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('importAnnotationSidecar', () {
    test('creates layers and annotations from sidecar', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Test.pdf'),
        filePath: const Value('/pdfs/Test.pdf'),
        lastModified: Value(DateTime.utc(2026, 3, 3)),
        fileSize: const Value(1000),
        pageCount: const Value(2),
      ));

      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3, 14, 30),
        layers: [
          SidecarLayer(
            name: 'Main',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 0,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(10, 20)],
                    color: Colors.red,
                    thickness: 3.0,
                    type: AnnotationType.pen,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await importAnnotationSidecar(db, docId, sidecar);

      final layers = await db.getAnnotationLayers(docId);
      expect(layers.length, 1);
      expect(layers[0].name, 'Main');

      final annotations = await db.getAnnotations(layers[0].id, 0);
      expect(annotations.length, 1);
    });

    test('replaces existing annotations on reimport', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Test.pdf'),
        filePath: const Value('/pdfs/Test.pdf'),
        lastModified: Value(DateTime.utc(2026, 3, 3)),
        fileSize: const Value(1000),
        pageCount: const Value(2),
      ));

      // First import
      final sidecar1 = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3, 14, 0),
        layers: [
          SidecarLayer(
            name: 'Old Layer',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(pageNumber: 0, strokes: [
                DrawingStroke(
                  points: [const Offset(1, 2)],
                  color: Colors.black,
                  thickness: 1.0,
                  type: AnnotationType.pen,
                ),
              ]),
            ],
          ),
        ],
      );
      await importAnnotationSidecar(db, docId, sidecar1);

      // Second import (should replace)
      final sidecar2 = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3, 15, 0),
        layers: [
          SidecarLayer(
            name: 'New Layer',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(pageNumber: 0, strokes: [
                DrawingStroke(
                  points: [const Offset(5, 6)],
                  color: Colors.blue,
                  thickness: 2.0,
                  type: AnnotationType.highlighter,
                ),
              ]),
            ],
          ),
        ],
      );
      await importAnnotationSidecar(db, docId, sidecar2);

      final layers = await db.getAnnotationLayers(docId);
      expect(layers.length, 1);
      expect(layers[0].name, 'New Layer');
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_service_import_test.dart`
Expected: FAIL — `importAnnotationSidecar` not defined

**Step 3: Implement importAnnotationSidecar**

Add to `lib/services/sync_service.dart`:

```dart
/// Import an AnnotationSidecar into the database for a given document.
/// Deletes all existing layers/annotations for the document first.
Future<void> importAnnotationSidecar(
  AppDatabase db,
  int documentId,
  AnnotationSidecar sidecar,
) async {
  // Delete existing layers (cascade deletes annotations)
  final existingLayers = await db.getAnnotationLayers(documentId);
  for (final layer in existingLayers) {
    await db.deleteAnnotationLayer(layer.id);
  }

  // Import new layers and annotations
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
```

Note: Needs `import 'package:drift/drift.dart' as drift;` and use `drift.Value` — or since this file won't import Flutter's Column, just `import 'package:drift/drift.dart';` and use `Value(...)` directly.

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_service_import_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_import_test.dart
git commit -m "feat: import annotation sidecars into database"
```

---

### Task 6: Import Set Lists from Files

Add a function to import a `.setlist.json` file into the database, matching document paths to existing documents.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Modify: `test/services/sync_service_import_test.dart`

**Step 1: Write failing tests**

Add to `test/services/sync_service_import_test.dart`:

```dart
group('importSetListFile', () {
  test('creates set list and items matching documents by path', () async {
    final docId = await db.insertDocument(DocumentsCompanion(
      name: const Value('Bach.pdf'),
      filePath: const Value('/music/pdfs/Bach.pdf'),
      lastModified: Value(DateTime.utc(2026, 3, 3)),
      fileSize: const Value(1000),
      pageCount: const Value(5),
    ));

    final setListFile = SetListFile(
      version: 1,
      modifiedAt: DateTime.utc(2026, 3, 3),
      name: 'Concert',
      description: 'Winter recital',
      items: [
        SetListFileItem(
          documentPath: 'Bach.pdf',
          orderIndex: 0,
          notes: 'Open with this',
        ),
      ],
    );

    final setListId = await importSetListFile(
      db, setListFile, '/music/pdfs',
    );

    expect(setListId, isNotNull);
    final setList = await db.getSetList(setListId!);
    expect(setList!.name, 'Concert');

    final items = await db.getSetListItems(setListId);
    expect(items.length, 1);
    expect(items[0].documentId, docId);
    expect(items[0].notes, 'Open with this');
  });

  test('skips items whose documents are not yet synced', () async {
    final setListFile = SetListFile(
      version: 1,
      modifiedAt: DateTime.utc(2026, 3, 3),
      name: 'Practice',
      description: null,
      items: [
        SetListFileItem(
          documentPath: 'missing.pdf',
          orderIndex: 0,
          notes: null,
        ),
      ],
    );

    final setListId = await importSetListFile(
      db, setListFile, '/music/pdfs',
    );

    expect(setListId, isNotNull);
    final items = await db.getSetListItems(setListId!);
    expect(items, isEmpty);
  });

  test('replaces existing set list with same name', () async {
    // Create initial set list
    await db.insertSetList(SetListsCompanion(
      name: const Value('Concert'),
    ));

    final setListFile = SetListFile(
      version: 1,
      modifiedAt: DateTime.utc(2026, 3, 3),
      name: 'Concert',
      description: 'Updated',
      items: [],
    );

    await importSetListFile(db, setListFile, '/music/pdfs');

    final allSetLists = await db.getAllSetLists();
    final concerts = allSetLists.where((s) => s.name == 'Concert').toList();
    expect(concerts.length, 1);
    expect(concerts[0].description, 'Updated');
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_service_import_test.dart`
Expected: FAIL — `importSetListFile` not defined

**Step 3: Implement importSetListFile**

Add to `lib/services/sync_service.dart`:

```dart
/// Import a SetListFile into the database.
/// Matches documents by relative path. Skips items whose documents don't exist.
/// If a set list with the same name exists, it is replaced.
/// Returns the set list ID, or null if import failed.
Future<int?> importSetListFile(
  AppDatabase db,
  SetListFile setListFile,
  String pdfDirectoryPath,
) async {
  // Delete existing set list with same name
  final existingSetLists = await db.getAllSetLists();
  for (final existing in existingSetLists) {
    if (existing.name == setListFile.name) {
      await db.deleteSetList(existing.id);
    }
  }

  // Create set list
  final setListId = await db.insertSetList(SetListsCompanion(
    name: Value(setListFile.name),
    description: Value(setListFile.description),
    modifiedAt: Value(setListFile.modifiedAt),
  ));

  // Match documents by path and add items
  final allDocs = await db.getAllDocuments();
  final normalized = pdfDirectoryPath.endsWith('/')
      ? pdfDirectoryPath
      : '$pdfDirectoryPath/';

  for (final item in setListFile.items) {
    final expectedPath = '$normalized${item.documentPath}';
    final doc = allDocs.cast<Document?>().firstWhere(
      (d) => d!.filePath == expectedPath,
      orElse: () => null,
    );

    if (doc != null) {
      await db.insertSetListItem(SetListItemsCompanion(
        setListId: Value(setListId),
        documentId: Value(doc.id),
        orderIndex: Value(item.orderIndex),
        notes: Value(item.notes),
      ));
    }
  }

  return setListId;
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_service_import_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_import_test.dart
git commit -m "feat: import set list files into database"
```

---

### Task 7: SyncManager — File I/O and Debouncing

Create a `SyncManager` singleton that handles writing sidecars/set list files to disk, reading them, and debouncing writes.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Create: `test/services/sync_manager_test.dart`

**Step 1: Write failing tests for write/read operations**

```dart
// test/services/sync_manager_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('sync_mgr_test_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SyncManager file I/O', () {
    test('writeAnnotationSidecar creates .feuillet.json file', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Test.pdf'),
        filePath: Value('${tempDir.path}/Test.pdf'),
        lastModified: Value(DateTime.utc(2026, 3, 3)),
        fileSize: const Value(1000),
        pageCount: const Value(1),
      ));

      final layerId = await db.insertAnnotationLayer(AnnotationLayersCompanion(
        documentId: Value(docId),
        name: const Value('Main'),
        orderIndex: const Value(0),
        isVisible: const Value(true),
      ));

      final stroke = DrawingStroke(
        points: [const Offset(10, 20)],
        color: Colors.red,
        thickness: 3.0,
        type: AnnotationType.pen,
      );
      await db.insertAnnotation(AnnotationsCompanion(
        layerId: Value(layerId),
        pageNumber: const Value(0),
        type: const Value('pen'),
        data: Value(jsonEncode(stroke.toJson())),
      ));

      await writeAnnotationSidecarToDisk(
        db: db,
        documentId: docId,
        scoreFilePath: '${tempDir.path}/Test.pdf',
      );

      final sidecarFile = File('${tempDir.path}/Test.feuillet.json');
      expect(await sidecarFile.exists(), isTrue);

      final content = jsonDecode(await sidecarFile.readAsString());
      expect(content['version'], 1);
      expect(content['layers'], isList);
    });

    test('writeAnnotationSidecar deletes file when no annotations', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Empty.pdf'),
        filePath: Value('${tempDir.path}/Empty.pdf'),
        lastModified: Value(DateTime.utc(2026, 3, 3)),
        fileSize: const Value(1000),
        pageCount: const Value(1),
      ));

      // Create a sidecar file first
      final sidecarFile = File('${tempDir.path}/Empty.feuillet.json');
      await sidecarFile.writeAsString('{}');
      expect(await sidecarFile.exists(), isTrue);

      await writeAnnotationSidecarToDisk(
        db: db,
        documentId: docId,
        scoreFilePath: '${tempDir.path}/Empty.pdf',
      );

      expect(await sidecarFile.exists(), isFalse);
    });

    test('readAnnotationSidecarFromDisk parses file', () async {
      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [],
      );
      final file = File('${tempDir.path}/Test.feuillet.json');
      await file.writeAsString(jsonEncode(sidecar.toJson()));

      final result = await readAnnotationSidecarFromDisk(
        '${tempDir.path}/Test.pdf',
      );

      expect(result, isNotNull);
      expect(result!.version, 1);
    });

    test('readAnnotationSidecarFromDisk returns null when file missing', () async {
      final result = await readAnnotationSidecarFromDisk(
        '${tempDir.path}/Nonexistent.pdf',
      );
      expect(result, isNull);
    });
  });

  group('SyncManager set list file I/O', () {
    test('writeSetListFileToDisk creates .setlist.json file', () async {
      final setListId = await db.insertSetList(SetListsCompanion(
        name: const Value('Concert'),
        description: const Value('Test'),
      ));

      await writeSetListFileToDisk(
        db: db,
        setListId: setListId,
        pdfDirectoryPath: tempDir.path,
      );

      final file = File('${tempDir.path}/setlists/Concert.setlist.json');
      expect(await file.exists(), isTrue);
    });

    test('deleteSetListFileFromDisk removes file', () async {
      final dir = Directory('${tempDir.path}/setlists');
      await dir.create();
      final file = File('${dir.path}/Concert.setlist.json');
      await file.writeAsString('{}');

      await deleteSetListFileFromDisk(
        setListName: 'Concert',
        pdfDirectoryPath: tempDir.path,
      );

      expect(await file.exists(), isFalse);
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_manager_test.dart`
Expected: FAIL — functions not defined

**Step 3: Implement file I/O functions**

Add to `lib/services/sync_service.dart`:

```dart
import 'dart:io';

/// Write annotation sidecar to disk for a document.
/// If the document has no annotations, deletes the sidecar file if it exists.
/// Uses atomic write (write to .tmp then rename).
Future<void> writeAnnotationSidecarToDisk({
  required AppDatabase db,
  required int documentId,
  required String scoreFilePath,
}) async {
  final sidecar = await buildAnnotationSidecar(db, documentId);
  final dir = p.dirname(scoreFilePath);
  final baseName = p.basenameWithoutExtension(scoreFilePath);
  final sidecarPath = p.join(dir, '$baseName.feuillet.json');

  if (sidecar == null) {
    // No annotations — delete sidecar if it exists
    final file = File(sidecarPath);
    if (await file.exists()) {
      await file.delete();
    }
    return;
  }

  final jsonStr = const JsonEncoder.withIndent('  ').convert(sidecar.toJson());
  final tmpPath = '$sidecarPath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(jsonStr);
  await tmpFile.rename(sidecarPath);
}

/// Read an annotation sidecar from disk for a given score file path.
/// Returns null if the sidecar file doesn't exist.
Future<AnnotationSidecar?> readAnnotationSidecarFromDisk(
  String scoreFilePath,
) async {
  final dir = p.dirname(scoreFilePath);
  final baseName = p.basenameWithoutExtension(scoreFilePath);
  final sidecarPath = p.join(dir, '$baseName.feuillet.json');
  final file = File(sidecarPath);

  if (!await file.exists()) return null;

  try {
    final content = await file.readAsString();
    return AnnotationSidecar.fromJson(jsonDecode(content));
  } catch (e) {
    debugPrint('SyncService: Error reading sidecar $sidecarPath: $e');
    return null;
  }
}

/// Write a set list file to disk.
Future<void> writeSetListFileToDisk({
  required AppDatabase db,
  required int setListId,
  required String pdfDirectoryPath,
}) async {
  final setListFile = await buildSetListFile(db, setListId, pdfDirectoryPath);
  if (setListFile == null) return;

  final setListDir = p.join(pdfDirectoryPath, 'setlists');
  await Directory(setListDir).create(recursive: true);

  final fileName = setListFileName(setListFile.name);
  final filePath = p.join(setListDir, fileName);
  final jsonStr = const JsonEncoder.withIndent('  ').convert(setListFile.toJson());

  final tmpPath = '$filePath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(jsonStr);
  await tmpFile.rename(filePath);
}

/// Delete a set list file from disk.
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

/// Read a set list file from disk.
Future<SetListFile?> readSetListFileFromDisk(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return null;

  try {
    final content = await file.readAsString();
    return SetListFile.fromJson(jsonDecode(content));
  } catch (e) {
    debugPrint('SyncService: Error reading set list file $filePath: $e');
    return null;
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_manager_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_manager_test.dart
git commit -m "feat: sidecar and set list file I/O with atomic writes"
```

---

### Task 8: Extend FileWatcherService for Sidecar Files

Modify `FileWatcherService` to emit events for `.feuillet.json` and `.setlist.json` file changes, in addition to document files.

**Files:**
- Modify: `lib/services/file_watcher_service.dart`
- Modify: `test/services/file_watcher_service_test.dart`

**Step 1: Write failing tests**

Add to `test/services/file_watcher_service_test.dart` (or check existing structure first — the key change is that `.feuillet.json` and `.setlist.json` files should now pass through the event filter):

```dart
// Add these tests to the existing test file
group('sidecar file detection', () {
  test('isSidecarFile identifies .feuillet.json files', () {
    expect(FileWatcherService.isSidecarFile('Bach.feuillet.json'), isTrue);
    expect(FileWatcherService.isSidecarFile('test.feuillet.json'), isTrue);
    expect(FileWatcherService.isSidecarFile('Bach.pdf'), isFalse);
  });

  test('isSetListFile identifies .setlist.json files', () {
    expect(FileWatcherService.isSetListFile('Concert.setlist.json'), isTrue);
    expect(FileWatcherService.isSetListFile('test.setlist.json'), isTrue);
    expect(FileWatcherService.isSetListFile('Bach.pdf'), isFalse);
  });
});
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/file_watcher_service_test.dart`
Expected: FAIL — static methods not defined

**Step 3: Modify FileWatcherService**

In `lib/services/file_watcher_service.dart`:

1. Add static helper methods:

```dart
/// Check if a file name is an annotation sidecar.
static bool isSidecarFile(String fileName) {
  return fileName.endsWith('.feuillet.json');
}

/// Check if a file name is a set list file.
static bool isSetListFile(String fileName) {
  return fileName.endsWith('.setlist.json');
}
```

2. Add a new stream controller for sidecar/set list changes:

```dart
final _syncChangesController = StreamController<WatchEvent>.broadcast();

/// Stream of sidecar and set list file changes
Stream<WatchEvent> get syncChanges => _syncChangesController.stream;
```

3. In `_startPdfDirectoryWatcher()`, modify the event listener (around line 127-143) to also emit sidecar/set list events:

Change the filter block from:
```dart
// Only process PDF files
final ext = p.extension(event.path).toLowerCase().replaceAll('.', '');
if (DocumentTypes.allExtensions.contains(ext)) {
  _pdfChangesController.add(event);
}
```

To:
```dart
final fileName = p.basename(event.path);

// Sidecar and set list files
if (isSidecarFile(fileName) || isSetListFile(fileName)) {
  _syncChangesController.add(event);
  return;
}

// Document files
final ext = p.extension(event.path).toLowerCase().replaceAll('.', '');
if (DocumentTypes.allExtensions.contains(ext)) {
  _pdfChangesController.add(event);
}
```

4. Close the controller in `dispose()`:
```dart
_syncChangesController.close();
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/file_watcher_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/file_watcher_service.dart test/services/file_watcher_service_test.dart
git commit -m "feat: extend file watcher to detect sidecar and set list files"
```

---

### Task 9: SyncManager Singleton — Orchestration and Loop Suppression

Create the `SyncManager` singleton that ties everything together: listens for file watcher events, debounces writes, suppresses loops, and handles startup reconciliation.

**Files:**
- Modify: `lib/services/sync_service.dart`
- Create: `test/services/sync_manager_integration_test.dart`

**Step 1: Write failing test for loop suppression**

```dart
// test/services/sync_manager_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  group('SyncManager suppression', () {
    late SyncManager manager;

    setUp(() {
      manager = SyncManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('suppressPath prevents processing for duration', () async {
      manager.suppressPath('/test/file.feuillet.json');

      expect(manager.isSuppressed('/test/file.feuillet.json'), isTrue);

      // After suppression expires
      await Future.delayed(const Duration(seconds: 2));
      expect(manager.isSuppressed('/test/file.feuillet.json'), isFalse);
    });

    test('different paths are not suppressed', () {
      manager.suppressPath('/test/a.feuillet.json');
      expect(manager.isSuppressed('/test/b.feuillet.json'), isFalse);
    });
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/sync_manager_integration_test.dart`
Expected: FAIL — SyncManager not defined

**Step 3: Implement SyncManager**

Add to `lib/services/sync_service.dart`:

```dart
import 'dart:async';

/// Manages sync between the local database and sidecar/set list files.
/// Handles debouncing, loop suppression, and startup reconciliation.
class SyncManager {
  SyncManager();

  final Map<String, DateTime> _suppressedPaths = {};
  final Map<int, Timer> _annotationDebounceTimers = {};
  final Map<int, Timer> _setListDebounceTimers = {};
  StreamSubscription? _syncChangesSubscription;

  static const _suppressionDuration = Duration(seconds: 2);
  static const _debounceDuration = Duration(seconds: 2);

  /// Mark a path as suppressed (don't process incoming changes for it).
  void suppressPath(String path) {
    _suppressedPaths[path] = DateTime.now().add(_suppressionDuration);
  }

  /// Check if a path is currently suppressed.
  bool isSuppressed(String path) {
    final expiry = _suppressedPaths[path];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _suppressedPaths.remove(path);
      return false;
    }
    return true;
  }

  /// Schedule a debounced annotation sidecar write.
  void scheduleAnnotationWrite({
    required AppDatabase db,
    required int documentId,
    required String scoreFilePath,
  }) {
    _annotationDebounceTimers[documentId]?.cancel();
    _annotationDebounceTimers[documentId] = Timer(_debounceDuration, () async {
      final dir = p.dirname(scoreFilePath);
      final baseName = p.basenameWithoutExtension(scoreFilePath);
      final sidecarPath = p.join(dir, '$baseName.feuillet.json');

      suppressPath(sidecarPath);
      await writeAnnotationSidecarToDisk(
        db: db,
        documentId: documentId,
        scoreFilePath: scoreFilePath,
      );
    });
  }

  /// Schedule a debounced set list file write.
  void scheduleSetListWrite({
    required AppDatabase db,
    required int setListId,
    required String pdfDirectoryPath,
  }) {
    _setListDebounceTimers[setListId]?.cancel();
    _setListDebounceTimers[setListId] = Timer(_debounceDuration, () async {
      // Get set list name for suppression
      final setList = await db.getSetList(setListId);
      if (setList == null) return;

      final fileName = setListFileName(setList.name);
      final filePath = p.join(pdfDirectoryPath, 'setlists', fileName);

      suppressPath(filePath);
      await writeSetListFileToDisk(
        db: db,
        setListId: setListId,
        pdfDirectoryPath: pdfDirectoryPath,
      );
    });
  }

  /// Start listening for incoming sidecar/set list file changes.
  void startListening({
    required Stream<dynamic> syncChanges,
    required AppDatabase db,
    required Future<String> Function() getPdfDirectoryPath,
  }) {
    _syncChangesSubscription = syncChanges.listen((event) async {
      final path = (event as dynamic).path as String;
      final fileName = p.basename(path);

      if (isSuppressed(path)) {
        debugPrint('SyncManager: Suppressed event for $fileName');
        return;
      }

      final pdfDir = await getPdfDirectoryPath();

      if (FileWatcherService.isSidecarFile(fileName)) {
        await _handleIncomingSidecar(path, db, pdfDir);
      } else if (FileWatcherService.isSetListFile(fileName)) {
        await _handleIncomingSetList(path, db, pdfDir);
      }
    });
  }

  Future<void> _handleIncomingSidecar(
    String sidecarPath,
    AppDatabase db,
    String pdfDir,
  ) async {
    // Derive the score file path from the sidecar path
    final dir = p.dirname(sidecarPath);
    final sidecarName = p.basenameWithoutExtension(
      p.basenameWithoutExtension(sidecarPath),
    ); // strips .feuillet.json -> base name

    // Actually, sidecarPath is like "Bach.feuillet.json"
    // p.basenameWithoutExtension gives "Bach.feuillet"
    // We need to strip ".feuillet" too
    final baseName = p.basename(sidecarPath).replaceAll('.feuillet.json', '');

    // Find the document in database by matching path prefix
    final allDocs = await db.getAllDocuments();
    final doc = allDocs.cast<Document?>().firstWhere(
      (d) => p.basenameWithoutExtension(d!.filePath) == baseName &&
             p.dirname(d.filePath) == dir,
      orElse: () => null,
    );

    if (doc == null) {
      debugPrint('SyncManager: No matching document for sidecar $sidecarPath');
      return;
    }

    final sidecar = await readAnnotationSidecarFromDisk(doc.filePath);
    if (sidecar == null) return;

    // Check modifiedAt — only import if file is newer
    // For now, always import (last-write-wins based on file system event)
    await importAnnotationSidecar(db, doc.id, sidecar);
    debugPrint('SyncManager: Imported annotations for ${doc.name}');
  }

  Future<void> _handleIncomingSetList(
    String setListPath,
    AppDatabase db,
    String pdfDir,
  ) async {
    final setListFile = await readSetListFileFromDisk(setListPath);
    if (setListFile == null) return;

    await importSetListFile(db, setListFile, pdfDir);
    debugPrint('SyncManager: Imported set list ${setListFile.name}');
  }

  /// Reconcile all sidecar and set list files on startup.
  Future<void> reconcileOnStartup({
    required AppDatabase db,
    required String pdfDirectoryPath,
  }) async {
    debugPrint('SyncManager: Starting reconciliation...');

    // Reconcile annotation sidecars
    final allDocs = await db.getAllDocuments();
    for (final doc in allDocs) {
      if (doc.filePath.startsWith('web://')) continue;

      final sidecar = await readAnnotationSidecarFromDisk(doc.filePath);
      if (sidecar != null) {
        // For simplicity: always import from file on startup
        // (file is the source of truth for sync)
        await importAnnotationSidecar(db, doc.id, sidecar);
      }
    }

    // Reconcile set list files
    final setListDir = Directory(p.join(pdfDirectoryPath, 'setlists'));
    if (await setListDir.exists()) {
      await for (final entity in setListDir.list()) {
        if (entity is File && entity.path.endsWith('.setlist.json')) {
          final setListFile = await readSetListFileFromDisk(entity.path);
          if (setListFile != null) {
            await importSetListFile(db, setListFile, pdfDirectoryPath);
          }
        }
      }
    }

    // Export local-only data to files (annotations without sidecars)
    for (final doc in allDocs) {
      if (doc.filePath.startsWith('web://')) continue;

      final existingSidecar = await readAnnotationSidecarFromDisk(doc.filePath);
      if (existingSidecar == null) {
        // Check if document has annotations in DB
        final sidecar = await buildAnnotationSidecar(db, doc.id);
        if (sidecar != null) {
          await writeAnnotationSidecarToDisk(
            db: db,
            documentId: doc.id,
            scoreFilePath: doc.filePath,
          );
        }
      }
    }

    debugPrint('SyncManager: Reconciliation complete');
  }

  void dispose() {
    _syncChangesSubscription?.cancel();
    for (final timer in _annotationDebounceTimers.values) {
      timer.cancel();
    }
    for (final timer in _setListDebounceTimers.values) {
      timer.cancel();
    }
    _suppressedPaths.clear();
  }
}
```

Note: This will need `import 'file_watcher_service.dart';` at the top of sync_service.dart.

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/sync_manager_integration_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_manager_integration_test.dart
git commit -m "feat: SyncManager with debouncing, loop suppression, and reconciliation"
```

---

### Task 10: Wire SyncManager into App Startup and Services

Connect the SyncManager to the app lifecycle: initialize on startup, listen for file watcher events, and trigger writes from AnnotationService and SetListService.

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/services/sync_service.dart` (add singleton)
- Modify: `lib/screens/document_viewer_screen.dart` (trigger annotation sidecar write)
- Modify: `lib/services/setlist_service.dart` (trigger set list file write)

**Step 1: Add singleton to SyncManager**

In `lib/services/sync_service.dart`, add at the top of the `SyncManager` class:

```dart
static SyncManager? _instance;
static SyncManager get instance => _instance ??= SyncManager();

/// Reset instance (for testing).
static void resetInstance() {
  _instance?.dispose();
  _instance = null;
}
```

**Step 2: Wire into main.dart**

In `lib/main.dart`, add after `DocumentService.instance;` (around line 22):

```dart
import 'services/sync_service.dart';

// ... inside main(), after DocumentService.instance:

// Initialize sync manager for Syncthing annotation/setlist sync
final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
SyncManager.instance.startListening(
  syncChanges: FileWatcherService.instance.syncChanges,
  db: DatabaseService.instance.database,
  getPdfDirectoryPath: () => FileWatcherService.instance.getPdfDirectoryPath(),
);
await SyncManager.instance.reconcileOnStartup(
  db: DatabaseService.instance.database,
  pdfDirectoryPath: pdfDir,
);
```

Also add cleanup in `AppLifecycleManager`:
- In `AppLifecycleState.detached` (line 99-103), add: `SyncManager.instance.dispose();`

**Step 3: Trigger annotation writes from DocumentViewerScreen**

Find where annotations are saved in `lib/screens/document_viewer_screen.dart`. After each annotation save (when `onStrokeCompleted` fires), schedule a sidecar write:

```dart
// After the annotation is saved to DB, schedule sidecar write:
import '../services/sync_service.dart';

// In the onStrokeCompleted callback or wherever annotations are persisted:
SyncManager.instance.scheduleAnnotationWrite(
  db: DatabaseService.instance.database,
  documentId: widget.document.id,
  scoreFilePath: widget.document.filePath,
);
```

Look for the exact location where `AnnotationService.saveAnnotation()` is called and add the schedule call after it. Also do this in any place annotations are cleared/deleted.

**Step 4: Trigger set list writes from SetListService**

In `lib/services/setlist_service.dart`, add sync triggers after mutations. The simplest approach is to add a helper that fires after each write operation:

```dart
import 'sync_service.dart';
import 'database_service.dart';
import 'file_watcher_service.dart';

// Add to end of createSetList, updateSetList, addDocumentToSetList,
// removeDocumentFromSetList, reorderSetListItems, duplicateSetList:

void _scheduleSyncWrite(int setListId) {
  FileWatcherService.instance.getPdfDirectoryPath().then((pdfDir) {
    SyncManager.instance.scheduleSetListWrite(
      db: _database,
      setListId: setListId,
      pdfDirectoryPath: pdfDir,
    );
  });
}
```

Then call `_scheduleSyncWrite(setListId)` at the end of each mutation method. For `deleteSetList`, instead call:

```dart
// Before deleting, get the name for file deletion
final setList = await getSetList(id);
await _database.deleteSetList(id);
if (setList != null) {
  final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
  await deleteSetListFileFromDisk(
    setListName: setList.name,
    pdfDirectoryPath: pdfDir,
  );
}
```

**Step 5: Run all tests**

Run: `flutter test`
Expected: All existing tests still pass. New sync tests pass.

**Step 6: Commit**

```bash
git add lib/main.dart lib/services/sync_service.dart lib/screens/document_viewer_screen.dart lib/services/setlist_service.dart
git commit -m "feat: wire SyncManager into app startup, viewer, and set list service"
```

---

### Task 11: Manual Testing and Smoke Test

Verify end-to-end behavior on macOS.

**Step 1: Build and run**

```bash
make run-macos
```

**Step 2: Test annotation sidecar write**

1. Open a score, draw an annotation, close the viewer
2. Check the PDF directory for a `.feuillet.json` file next to the score
3. Verify the JSON content is well-formed

**Step 3: Test annotation sidecar import**

1. Manually edit the `.feuillet.json` file (change a color value)
2. Wait for the file watcher to detect the change (~1 second)
3. Reopen the document and verify the annotation reflects the edit

**Step 4: Test set list sync**

1. Create a set list with documents
2. Check `<pdf-dir>/setlists/` for the `.setlist.json` file
3. Manually edit the file (change order)
4. Verify the app picks up the change

**Step 5: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues found during manual testing"
```

---

### Task 12: Add .feuillet.json and .setlist.json to Syncthing Temp File Filter

Ensure that `.feuillet.json.tmp` files (from atomic writes) are ignored by the file watcher.

**Files:**
- Modify: `lib/services/file_watcher_service.dart:195-202`

**Step 1: Verify the existing filter**

The current `_isSyncthingTempFile` at line 195 already filters `*.tmp` files. Since atomic writes use `.feuillet.json.tmp`, these are already filtered. No change needed unless testing reveals otherwise.

**Step 2: Commit if changes were needed**

This task may be a no-op since `.tmp` is already filtered.
