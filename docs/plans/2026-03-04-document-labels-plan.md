# Document Labels Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a label system to documents with filtering, auto-labeling from directories, batch operations, and Syncthing sync via sidecar files.

**Architecture:** Two new Drift tables (`Labels`, `DocumentLabels`) with a `LabelService` singleton. Sidecar sync extends the existing `.feuillet.json` format. Library screen gets a horizontal filter bar with label chips. Auto-labeling derives labels from subdirectory names during library scan.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, path package

---

### Task 1: Database Schema — Labels and DocumentLabels Tables

**Files:**
- Modify: `lib/models/database.dart:119-145` (add tables, update annotation, bump schema)
- Test: `test/models/database_label_test.dart` (new)

**Step 1: Write the failing test**

Create `test/models/database_label_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Labels table', () {
    test('insert and retrieve a label', () async {
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
        color: const Value(4294901760),
      ));
      final labels = await db.getAllLabels();
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
      expect(labels.first.color, 4294901760);
    });

    test('label name is primary key — duplicate insert fails', () async {
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
      ));
      expect(
        () => db.insertLabel(LabelsCompanion(
          name: const Value('Classical'),
        )),
        throwsA(anything),
      );
    });

    test('delete label removes it', () async {
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
      ));
      await db.deleteLabel('Classical');
      final labels = await db.getAllLabels();
      expect(labels, isEmpty);
    });

    test('update label color', () async {
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
      ));
      await db.updateLabelColor('Classical', 4278190080);
      final labels = await db.getAllLabels();
      expect(labels.first.color, 4278190080);
    });
  });

  group('DocumentLabels table', () {
    late int docId;

    setUp(() async {
      docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Bach Suite'),
        filePath: const Value('/docs/Bach.pdf'),
        lastModified: Value(DateTime.now()),
        fileSize: const Value(1024),
        pageCount: const Value(10),
      ));
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
      ));
      await db.insertLabel(LabelsCompanion(
        name: const Value('Bach'),
      ));
    });

    test('add label to document and retrieve', () async {
      await db.addLabelToDocument(docId, 'Classical');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });

    test('add multiple labels to document', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.addLabelToDocument(docId, 'Bach');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels.length, 2);
    });

    test('remove label from document', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.removeLabelFromDocument(docId, 'Classical');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });

    test('deleting document cascades to document_labels', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.deleteDocument(docId);
      // Label itself should still exist
      final labels = await db.getAllLabels();
      expect(labels.length, 2);
    });

    test('deleting label cascades to document_labels', () async {
      await db.addLabelToDocument(docId, 'Classical');
      await db.deleteLabel('Classical');
      final labels = await db.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });

    test('getDocumentIdsWithAllLabels returns docs matching ALL labels', () async {
      final docId2 = await db.insertDocument(DocumentsCompanion(
        name: const Value('Mozart Sonata'),
        filePath: const Value('/docs/Mozart.pdf'),
        lastModified: Value(DateTime.now()),
        fileSize: const Value(2048),
        pageCount: const Value(20),
      ));
      await db.addLabelToDocument(docId, 'Classical');
      await db.addLabelToDocument(docId, 'Bach');
      await db.addLabelToDocument(docId2, 'Classical');

      final ids = await db.getDocumentIdsWithAllLabels(['Classical', 'Bach']);
      expect(ids, [docId]);
    });

    test('watchAllLabels emits updates', () async {
      final stream = db.watchAllLabels();
      final first = await stream.first;
      expect(first, isEmpty);

      await db.insertLabel(LabelsCompanion(
        name: const Value('Jazz'),
      ));
      final second = await stream.first;
      expect(second.length, 1);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/models/database_label_test.dart`
Expected: FAIL — `LabelsCompanion`, `insertLabel`, `getAllLabels`, etc. not defined

**Step 3: Write the implementation**

In `lib/models/database.dart`, add the two new table classes before `AppSettings` (around line 117):

```dart
// Labels — reusable tags for documents
class Labels extends Table {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get color => integer().nullable()();

  @override
  Set<Column> get primaryKey => {name};
}

// Document-label associations (many-to-many join table)
@DataClassName('DocumentLabel')
class DocumentLabels extends Table {
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get labelName =>
      text().references(Labels, #name, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {documentId, labelName};
}
```

Update `@DriftDatabase` annotation to include the new tables:

```dart
@DriftDatabase(
  tables: [
    Documents,
    DocumentSettings,
    AnnotationLayers,
    Annotations,
    SetLists,
    SetListItems,
    AppSettings,
    Labels,
    DocumentLabels,
  ],
)
```

Bump `schemaVersion` from `5` to `6`.

Add migration in `onUpgrade`:

```dart
if (from < 6) {
  await m.createTable(labels);
  await m.createTable(documentLabels);
}
```

Add these query methods to `AppDatabase`:

```dart
// Label operations
Future<void> insertLabel(LabelsCompanion label) {
  return into(labels).insert(label);
}

Future<List<Label>> getAllLabels() {
  return (select(labels)..orderBy([(l) => OrderingTerm.asc(l.name)])).get();
}

Stream<List<Label>> watchAllLabels() {
  return (select(labels)..orderBy([(l) => OrderingTerm.asc(l.name)])).watch();
}

Future<Label?> getLabel(String name) {
  return (select(labels)..where((l) => l.name.equals(name))).getSingleOrNull();
}

Future<void> deleteLabel(String name) {
  return (delete(labels)..where((l) => l.name.equals(name))).go();
}

Future<void> updateLabelColor(String name, int? color) async {
  await (update(labels)..where((l) => l.name.equals(name))).write(
    LabelsCompanion(color: Value(color)),
  );
}

Future<void> renameLabel(String oldName, String newName) async {
  final label = await getLabel(oldName);
  if (label == null) return;
  // Delete old, insert new, re-link — since text PKs don't support ON UPDATE CASCADE in Drift
  await customStatement(
    "UPDATE labels SET name = ? WHERE name = ?",
    [newName, oldName],
  );
  await customStatement(
    "UPDATE document_labels SET label_name = ? WHERE label_name = ?",
    [newName, oldName],
  );
}

// DocumentLabel operations
Future<void> addLabelToDocument(int documentId, String labelName) {
  return into(documentLabels).insert(
    DocumentLabelsCompanion(
      documentId: Value(documentId),
      labelName: Value(labelName),
    ),
    mode: InsertMode.insertOrIgnore,
  );
}

Future<void> removeLabelFromDocument(int documentId, String labelName) {
  return (delete(documentLabels)..where(
    (dl) => dl.documentId.equals(documentId) & dl.labelName.equals(labelName),
  )).go();
}

Future<List<Label>> getLabelsForDocument(int documentId) {
  final query = select(labels).join([
    innerJoin(
      documentLabels,
      documentLabels.labelName.equalsExp(labels.name),
    ),
  ])..where(documentLabels.documentId.equals(documentId))
    ..orderBy([OrderingTerm.asc(labels.name)]);
  return query.map((row) => row.readTable(labels)).get();
}

Stream<List<Label>> watchLabelsForDocument(int documentId) {
  final query = select(labels).join([
    innerJoin(
      documentLabels,
      documentLabels.labelName.equalsExp(labels.name),
    ),
  ])..where(documentLabels.documentId.equals(documentId))
    ..orderBy([OrderingTerm.asc(labels.name)]);
  return query.map((row) => row.readTable(labels)).watch();
}

Future<List<int>> getDocumentIdsWithAllLabels(List<String> labelNames) async {
  if (labelNames.isEmpty) return [];
  // Documents that have ALL of the given labels (AND logic)
  final query = selectOnly(documentLabels)
    ..addColumns([documentLabels.documentId])
    ..where(documentLabels.labelName.isIn(labelNames))
    ..groupBy([documentLabels.documentId])
    ..having(documentLabels.labelName.count().equals(labelNames.length));
  final rows = await query.get();
  return rows.map((r) => r.read(documentLabels.documentId)!).toList();
}
```

**Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`

**Step 5: Run test to verify it passes**

Run: `flutter test test/models/database_label_test.dart`
Expected: ALL PASS

**Step 6: Commit**

```bash
git add lib/models/database.dart lib/models/database.g.dart test/models/database_label_test.dart
git commit -m "feat: add Labels and DocumentLabels tables (schema v6)"
```

---

### Task 2: LabelService

**Files:**
- Create: `lib/services/label_service.dart`
- Test: `test/services/label_service_test.dart` (new)

**Step 1: Write the failing test**

Create `test/services/label_service_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/label_service.dart';

void main() {
  late AppDatabase db;
  late LabelService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = LabelService.forTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertDoc(String name, String path) async {
    return db.insertDocument(DocumentsCompanion(
      name: Value(name),
      filePath: Value(path),
      lastModified: Value(DateTime.now()),
      fileSize: const Value(1024),
      pageCount: const Value(10),
    ));
  }

  group('createLabel', () {
    test('creates a new label', () async {
      await service.createLabel('Classical');
      final labels = await service.getAllLabels();
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });

    test('creates label with color', () async {
      await service.createLabel('Classical', color: 4294901760);
      final labels = await service.getAllLabels();
      expect(labels.first.color, 4294901760);
    });

    test('does not throw on duplicate', () async {
      await service.createLabel('Classical');
      await service.createLabel('Classical'); // should not throw
      final labels = await service.getAllLabels();
      expect(labels.length, 1);
    });
  });

  group('addLabelToDocument', () {
    test('associates label with document', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      final labels = await service.getLabelsForDocument(docId);
      expect(labels.length, 1);
      expect(labels.first.name, 'Classical');
    });
  });

  group('addLabelToDocuments (batch)', () {
    test('adds label to multiple documents', () async {
      final id1 = await insertDoc('Bach', '/docs/Bach.pdf');
      final id2 = await insertDoc('Mozart', '/docs/Mozart.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocuments([id1, id2], 'Classical');

      final labels1 = await service.getLabelsForDocument(id1);
      final labels2 = await service.getLabelsForDocument(id2);
      expect(labels1.length, 1);
      expect(labels2.length, 1);
    });
  });

  group('removeLabelFromDocument', () {
    test('removes association', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      await service.removeLabelFromDocument(docId, 'Classical');
      final labels = await service.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });
  });

  group('deleteLabel', () {
    test('deletes label and associations', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      await service.deleteLabel('Classical');

      final allLabels = await service.getAllLabels();
      expect(allLabels, isEmpty);
      final docLabels = await service.getLabelsForDocument(docId);
      expect(docLabels, isEmpty);
    });
  });

  group('updateLabelColor', () {
    test('updates color', () async {
      await service.createLabel('Classical');
      await service.updateLabelColor('Classical', 4278190080);
      final labels = await service.getAllLabels();
      expect(labels.first.color, 4278190080);
    });
  });

  group('renameLabel', () {
    test('renames and preserves associations', () async {
      final docId = await insertDoc('Bach', '/docs/Bach.pdf');
      await service.createLabel('Classical');
      await service.addLabelToDocument(docId, 'Classical');
      await service.renameLabel('Classical', 'Baroque');

      final labels = await service.getLabelsForDocument(docId);
      expect(labels.first.name, 'Baroque');
    });
  });

  group('getDocumentIdsWithAllLabels', () {
    test('AND filter returns only docs with all labels', () async {
      final id1 = await insertDoc('Bach', '/docs/Bach.pdf');
      final id2 = await insertDoc('Mozart', '/docs/Mozart.pdf');
      await service.createLabel('Classical');
      await service.createLabel('Bach');
      await service.addLabelToDocument(id1, 'Classical');
      await service.addLabelToDocument(id1, 'Bach');
      await service.addLabelToDocument(id2, 'Classical');

      final ids = await service.getDocumentIdsWithAllLabels(['Classical', 'Bach']);
      expect(ids, [id1]);
    });

    test('empty label list returns empty', () async {
      final ids = await service.getDocumentIdsWithAllLabels([]);
      expect(ids, isEmpty);
    });
  });

  group('ensureLabelsFromPath', () {
    test('creates labels from subdirectory segments', () async {
      final docId = await insertDoc('Bach Suite', '/music/pdfs/Classical/Bach/Suite.pdf');
      await service.ensureLabelsFromPath(docId, '/music/pdfs/Classical/Bach/Suite.pdf', '/music/pdfs');

      final labels = await service.getLabelsForDocument(docId);
      final names = labels.map((l) => l.name).toSet();
      expect(names, {'Classical', 'Bach'});
    });

    test('no labels for files at root', () async {
      final docId = await insertDoc('Suite', '/music/pdfs/Suite.pdf');
      await service.ensureLabelsFromPath(docId, '/music/pdfs/Suite.pdf', '/music/pdfs');

      final labels = await service.getLabelsForDocument(docId);
      expect(labels, isEmpty);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/label_service_test.dart`
Expected: FAIL — `LabelService` not found

**Step 3: Write the implementation**

Create `lib/services/label_service.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../models/database.dart';
import 'database_service.dart';

class LabelService {
  LabelService._() : _database = DatabaseService.database;

  /// Constructor for testing with a custom database instance.
  LabelService.forTesting(this._database);

  static LabelService? _instance;
  static LabelService get instance => _instance ??= LabelService._();

  /// Reset singleton (for testing).
  static void resetInstance() {
    _instance = null;
  }

  final AppDatabase _database;

  // CRUD

  Future<void> createLabel(String name, {int? color}) async {
    await _database.insertLabel(LabelsCompanion(
      name: Value(name),
      color: Value(color),
    ));
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

  Future<void> addLabelToDocuments(List<int> documentIds, String labelName) async {
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

  /// Creates labels from subdirectory segments and associates them with [documentId].
  ///
  /// Given filePath `/music/pdfs/Classical/Bach/Suite.pdf` and pdfDir `/music/pdfs`,
  /// creates labels "Classical" and "Bach" and links them to the document.
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

    // p.dirname('.') returns '.' for files at root
    if (segments.length == 1 && segments.first == '.') return;

    for (final segment in segments) {
      if (segment == '.' || segment.isEmpty) continue;
      try {
        await createLabel(segment);
      } catch (_) {
        // Label already exists, ignore
      }
      await addLabelToDocument(documentId, segment);
    }
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/label_service_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/services/label_service.dart test/services/label_service_test.dart
git commit -m "feat: add LabelService with CRUD, batch, and auto-labeling"
```

---

### Task 3: Sidecar Sync — Labels in .feuillet.json

**Files:**
- Modify: `lib/services/sync_service.dart:89-115` (extend AnnotationSidecar model)
- Test: `test/services/sync_service_labels_test.dart` (new)

**Step 1: Write the failing test**

Create `test/services/sync_service_labels_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  group('AnnotationSidecar labels', () {
    test('toJson includes labels when present', () {
      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.utc(2026, 3, 4),
        layers: [],
        labels: [
          SidecarLabel(name: 'Classical', color: 4294901760),
          SidecarLabel(name: 'Bach'),
        ],
      );
      final json = sidecar.toJson();
      expect(json['version'], 2);
      expect(json['labels'], isA<List>());
      expect(json['labels'].length, 2);
      expect(json['labels'][0]['name'], 'Classical');
      expect(json['labels'][0]['color'], 4294901760);
      expect(json['labels'][1]['name'], 'Bach');
      expect(json['labels'][1]['color'], isNull);
    });

    test('fromJson reads labels', () {
      final json = {
        'version': 2,
        'modifiedAt': '2026-03-04T00:00:00.000Z',
        'layers': [],
        'labels': [
          {'name': 'Classical', 'color': 4294901760},
          {'name': 'Bach'},
        ],
      };
      final sidecar = AnnotationSidecar.fromJson(json);
      expect(sidecar.labels.length, 2);
      expect(sidecar.labels[0].name, 'Classical');
      expect(sidecar.labels[0].color, 4294901760);
      expect(sidecar.labels[1].name, 'Bach');
      expect(sidecar.labels[1].color, isNull);
    });

    test('fromJson handles missing labels field (v1 sidecars)', () {
      final json = {
        'version': 1,
        'modifiedAt': '2026-03-04T00:00:00.000Z',
        'layers': [],
      };
      final sidecar = AnnotationSidecar.fromJson(json);
      expect(sidecar.labels, isEmpty);
    });
  });

  group('SidecarLabel', () {
    test('toJson with color', () {
      final label = SidecarLabel(name: 'Jazz', color: 42);
      expect(label.toJson(), {'name': 'Jazz', 'color': 42});
    });

    test('toJson without color omits null', () {
      final label = SidecarLabel(name: 'Jazz');
      final json = label.toJson();
      expect(json['name'], 'Jazz');
      expect(json.containsKey('color'), isFalse);
    });
  });

  group('buildAnnotationSidecar includes labels', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('includes document labels in sidecar', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Bach Suite'),
        filePath: const Value('/docs/Bach.pdf'),
        lastModified: Value(DateTime.now()),
        fileSize: const Value(1024),
        pageCount: const Value(10),
      ));
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
        color: const Value(4294901760),
      ));
      await db.addLabelToDocument(docId, 'Classical');

      final sidecar = await buildAnnotationSidecar(db, docId);
      // Even with no annotations, sidecar should be built if labels exist
      expect(sidecar, isNotNull);
      expect(sidecar!.labels.length, 1);
      expect(sidecar.labels.first.name, 'Classical');
    });
  });

  group('importAnnotationSidecar imports labels', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('creates labels and associations from sidecar', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Bach Suite'),
        filePath: const Value('/docs/Bach.pdf'),
        lastModified: Value(DateTime.now()),
        fileSize: const Value(1024),
        pageCount: const Value(10),
      ));

      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.now(),
        layers: [],
        labels: [
          SidecarLabel(name: 'Classical', color: 4294901760),
          SidecarLabel(name: 'Bach'),
        ],
      );
      await importAnnotationSidecar(db, docId, sidecar);

      final labels = await db.getLabelsForDocument(docId);
      expect(labels.length, 2);
      final names = labels.map((l) => l.name).toSet();
      expect(names, {'Classical', 'Bach'});
    });

    test('import does not overwrite existing label color', () async {
      final docId = await db.insertDocument(DocumentsCompanion(
        name: const Value('Bach Suite'),
        filePath: const Value('/docs/Bach.pdf'),
        lastModified: Value(DateTime.now()),
        fileSize: const Value(1024),
        pageCount: const Value(10),
      ));
      // Pre-existing label with a color
      await db.insertLabel(LabelsCompanion(
        name: const Value('Classical'),
        color: const Value(4278190080), // local color
      ));

      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.now(),
        layers: [],
        labels: [
          SidecarLabel(name: 'Classical', color: 4294901760), // different color
        ],
      );
      await importAnnotationSidecar(db, docId, sidecar);

      final label = await db.getLabel('Classical');
      expect(label!.color, 4278190080); // local color kept
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/services/sync_service_labels_test.dart`
Expected: FAIL — `SidecarLabel` not found, `AnnotationSidecar` constructor missing `labels`

**Step 3: Write the implementation**

Add `SidecarLabel` class to `sync_service.dart` (before `AnnotationSidecar`):

```dart
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
```

Modify `AnnotationSidecar` to include `labels`:

```dart
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
      labels: (json['labels'] as List?)
          ?.map((l) => SidecarLabel.fromJson(l as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
```

Modify `buildAnnotationSidecar` to include labels. Add import for `drift/drift.dart` if not already there:

```dart
Future<AnnotationSidecar?> buildAnnotationSidecar(
  AppDatabase db,
  int documentId,
) async {
  final layers = await db.getAnnotationLayers(documentId);
  final docLabels = await db.getLabelsForDocument(documentId);

  // Build sidecar layers (existing code)...
  // ...existing layer building code stays the same...

  if (sidecarLayers.isEmpty && docLabels.isEmpty) return null;

  return AnnotationSidecar(
    version: 2,
    modifiedAt: DateTime.now().toUtc(),
    layers: sidecarLayers,
    labels: docLabels.map((l) => SidecarLabel(name: l.name, color: l.color)).toList(),
  );
}
```

Modify `importAnnotationSidecar` to import labels:

```dart
Future<void> importAnnotationSidecar(
  AppDatabase db,
  int documentId,
  AnnotationSidecar sidecar,
) async {
  // ...existing layer import code stays the same...

  // Import labels
  for (final sidecarLabel in sidecar.labels) {
    final existing = await db.getLabel(sidecarLabel.name);
    if (existing == null) {
      await db.insertLabel(LabelsCompanion(
        name: Value(sidecarLabel.name),
        color: Value(sidecarLabel.color),
      ));
    }
    // Don't overwrite existing label color
    await db.addLabelToDocument(documentId, sidecarLabel.name);
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/services/sync_service_labels_test.dart`
Expected: ALL PASS

**Step 5: Run existing sync tests to check for regressions**

Run: `flutter test test/services/sync_service_test.dart test/services/sync_service_export_test.dart test/services/sync_service_import_test.dart test/services/sync_manager_test.dart`
Expected: ALL PASS (existing tests should work since `labels` parameter defaults to `const []`)

**Step 6: Commit**

```bash
git add lib/services/sync_service.dart test/services/sync_service_labels_test.dart
git commit -m "feat: add label sync to .feuillet.json sidecar files"
```

---

### Task 4: Auto-Labeling in Document Import

**Files:**
- Modify: `lib/services/document_service.dart` (call `ensureLabelsFromPath` during scan)

**Step 1: Write the failing test**

Add test to `test/services/label_service_test.dart` (already has `ensureLabelsFromPath` tests). The integration is simple enough that the existing tests cover the logic. We just need to wire it up.

**Step 2: Write the implementation**

In `lib/services/document_service.dart`, import `LabelService`:

```dart
import 'label_service.dart';
```

In `_doScanAndSyncLibrary()`, after a new document is added via `addDocumentToLibrary(file.path)`, call auto-labeling. Find the section that adds new documents and add:

```dart
// After: await addDocumentToLibrary(file.path);
final doc = await _database.getAllDocuments()
    .then((docs) => docs.where((d) => d.filePath == file.path).firstOrNull);
if (doc != null) {
  await LabelService.instance.ensureLabelsFromPath(doc.id, doc.filePath, pdfDirPath);
}
```

Also in `_handleNewPdf(String filePath)`, after calling `addDocumentToLibrary`, add the same auto-labeling:

```dart
final doc = await _database.getAllDocuments()
    .then((docs) => docs.where((d) => d.filePath == filePath).firstOrNull);
if (doc != null) {
  final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
  await LabelService.instance.ensureLabelsFromPath(doc.id, doc.filePath, pdfDir);
}
```

**Step 3: Run all tests**

Run: `flutter test`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add lib/services/document_service.dart
git commit -m "feat: auto-label documents from subdirectory names on import"
```

---

### Task 5: Riverpod Providers for Labels

**Files:**
- Create: `lib/providers/label_providers.dart`

**Step 1: Write the implementation**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../services/label_service.dart';

/// Watches all labels in the database (for the filter bar).
final allLabelsProvider = StreamProvider<List<Label>>((ref) {
  return LabelService.instance.watchAllLabels();
});

/// Watches labels for a specific document.
final documentLabelsProvider = StreamProvider.family<List<Label>, int>((ref, documentId) {
  return LabelService.instance.watchLabelsForDocument(documentId);
});
```

**Step 2: Commit**

```bash
git add lib/providers/label_providers.dart
git commit -m "feat: add Riverpod providers for labels"
```

---

### Task 6: Library Screen — Label Filter Bar

**Files:**
- Modify: `lib/screens/library_screen.dart`

**Step 1: Write the implementation**

Add state for selected labels in `_LibraryScreenState`:

```dart
Set<String> _selectedLabelNames = {};
```

Add import:

```dart
import '../providers/label_providers.dart';
```

In `build()`, after the search bar `Padding` (around line 1041) and before the `Expanded` document grid, insert the label filter bar:

```dart
// Label filter bar
Consumer(builder: (context, ref, _) {
  final labelsAsync = ref.watch(allLabelsProvider);
  return labelsAsync.when(
    data: (labels) {
      if (labels.isEmpty) return const SizedBox.shrink();
      return _buildLabelFilterBar(labels);
    },
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(),
  );
}),
```

Add the filter bar builder method:

```dart
Widget _buildLabelFilterBar(List<Label> labels) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: SizedBox(
      height: 40,
      child: Row(
        children: [
          if (_selectedLabelNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _selectedLabelNames.clear()),
                tooltip: 'Clear filters',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final label = labels[index];
                final isSelected = _selectedLabelNames.contains(label.name);
                return FilterChip(
                  label: Text(label.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedLabelNames.add(label.name);
                      } else {
                        _selectedLabelNames.remove(label.name);
                      }
                    });
                  },
                  avatar: label.color != null
                      ? CircleAvatar(
                          backgroundColor: Color(label.color!),
                          radius: 6,
                        )
                      : null,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
```

Modify `_filterDocuments` to apply label filtering. This is the tricky part — label filtering requires async (database query), but `_filterDocuments` is currently sync. Two options:

**Option A (recommended):** Pre-compute filtered document IDs and pass them to `_filterDocuments`. In `build()`, when `_selectedLabelNames` is not empty, use a `FutureProvider` or compute it inside the `data:` callback:

```dart
// In the documentsAsync.when data: callback
data: (documents) {
  if (_selectedLabelNames.isEmpty) {
    final filteredDocs = _filterDocuments(documents);
    // ...existing code
  } else {
    return FutureBuilder<List<int>>(
      future: LabelService.instance.getDocumentIdsWithAllLabels(
        _selectedLabelNames.toList(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allowedIds = snapshot.data!.toSet();
        final labelFiltered = documents.where((d) => allowedIds.contains(d.id)).toList();
        final filteredDocs = _filterDocuments(labelFiltered);
        if (filteredDocs.isEmpty) {
          return _buildEmptyState(false);
        }
        return _buildDocumentList(filteredDocs);
      },
    );
  }
},
```

**Step 2: Run the app to test**

Run: `make run-web`
Verify: Label filter bar appears below search, chips are tappable, AND filtering works.

**Step 3: Commit**

```bash
git add lib/screens/library_screen.dart
git commit -m "feat: add label filter bar to library screen"
```

---

### Task 7: Batch Labeling in Selection Mode

**Files:**
- Modify: `lib/screens/library_screen.dart` (selection toolbar + dialog)

**Step 1: Write the implementation**

Add a "Label" button to the selection action bar. Find `_buildSelectionActionBar()` and add a label icon:

```dart
IconButton(
  icon: const Icon(Icons.label),
  onPressed: _labelSelected,
  tooltip: 'Add labels',
),
```

Add `_labelSelected` method:

```dart
Future<void> _labelSelected() async {
  final allLabels = await LabelService.instance.getAllLabels();
  if (!mounted) return;

  final result = await showDialog<Set<String>>(
    context: context,
    builder: (context) => _LabelPickerDialog(
      allLabels: allLabels,
      documentIds: _selectedDocumentIds.toList(),
    ),
  );

  if (result != null && result.isNotEmpty) {
    for (final labelName in result) {
      await LabelService.instance.addLabelToDocuments(
        _selectedDocumentIds.toList(),
        labelName,
      );
    }
    _exitSelectionMode();
  }
}
```

Add the dialog class at the bottom of the file:

```dart
class _LabelPickerDialog extends StatefulWidget {
  final List<Label> allLabels;
  final List<int> documentIds;

  const _LabelPickerDialog({
    required this.allLabels,
    required this.documentIds,
  });

  @override
  State<_LabelPickerDialog> createState() => _LabelPickerDialogState();
}

class _LabelPickerDialogState extends State<_LabelPickerDialog> {
  final Set<String> _selected = {};
  final _newLabelController = TextEditingController();

  @override
  void dispose() {
    _newLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Labels'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Existing labels as checkboxes
            if (widget.allLabels.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.allLabels.length,
                  itemBuilder: (context, index) {
                    final label = widget.allLabels[index];
                    return CheckboxListTile(
                      title: Text(label.name),
                      secondary: label.color != null
                          ? CircleAvatar(
                              backgroundColor: Color(label.color!),
                              radius: 8,
                            )
                          : null,
                      value: _selected.contains(label.name),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(label.name);
                          } else {
                            _selected.remove(label.name);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            // Create new label
            TextField(
              controller: _newLabelController,
              decoration: const InputDecoration(
                labelText: 'New label name',
                isDense: true,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() => _selected.add(value.trim()));
                  _newLabelController.clear();
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
```

**Step 2: Run the app to test**

Run: `make run-web`
Verify: Multi-select documents, tap label icon, pick labels, apply.

**Step 3: Commit**

```bash
git add lib/screens/library_screen.dart
git commit -m "feat: add batch label assignment in library selection mode"
```

---

### Task 8: Single Document Labeling (Document Viewer)

**Files:**
- Modify: `lib/screens/document_viewer_screen.dart`

This task adds a label chip row to the document viewer screen so users can view, add, and remove labels for an individual document.

**Step 1: Explore the document viewer screen structure**

Read `lib/screens/document_viewer_screen.dart` to find where to insert the label chips UI. Look for the AppBar actions or a bottom panel area.

**Step 2: Write the implementation**

Add a label row to the AppBar bottom or as a small strip above the document content. The exact insertion point depends on the document viewer layout. Use `documentLabelsProvider` for reactive updates.

Key UI elements:
- Row of `Chip` widgets for existing labels (with "x" to remove)
- "+" `ActionChip` that shows an autocomplete dialog for adding labels
- Wrap in a `Consumer` widget watching `documentLabelsProvider(documentId)`

**Step 3: Run the app to test**

Run: `make run-web`
Verify: Open a document, see its labels, add/remove labels.

**Step 4: Commit**

```bash
git add lib/screens/document_viewer_screen.dart
git commit -m "feat: add label management to document viewer"
```

---

### Task 9: Label Management Screen

**Files:**
- Create: `lib/screens/label_management_screen.dart`
- Modify: `lib/screens/settings_screen.dart` (add navigation link)

**Step 1: Write the implementation**

Create `lib/screens/label_management_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/database.dart';
import '../providers/label_providers.dart';
import '../services/label_service.dart';

class LabelManagementScreen extends ConsumerWidget {
  const LabelManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(allLabelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Labels')),
      body: labelsAsync.when(
        data: (labels) {
          if (labels.isEmpty) {
            return const Center(child: Text('No labels yet'));
          }
          return ListView.builder(
            itemCount: labels.length,
            itemBuilder: (context, index) {
              final label = labels[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: label.color != null
                      ? Color(label.color!)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  radius: 16,
                ),
                title: Text(label.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.palette),
                      onPressed: () => _pickColor(context, label),
                      tooltip: 'Change color',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _renameLabel(context, label),
                      tooltip: 'Rename',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteLabel(context, label),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, Label label) async {
    // Show a simple color picker dialog with preset colors
    final colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.cyan, Colors.teal,
      Colors.green, Colors.lime, Colors.amber, Colors.orange,
    ];
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((c) => GestureDetector(
            onTap: () => Navigator.pop(context, c),
            child: CircleAvatar(backgroundColor: c, radius: 20),
          )).toList(),
        ),
      ),
    );
    if (picked != null) {
      await LabelService.instance.updateLabelColor(
        label.name,
        picked.toARGB32(),
      );
    }
  }

  Future<void> _renameLabel(BuildContext context, Label label) async {
    final controller = TextEditingController(text: label.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Label'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.isNotEmpty && newName != label.name) {
      await LabelService.instance.renameLabel(label.name, newName);
    }
  }

  Future<void> _deleteLabel(BuildContext context, Label label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Label'),
        content: Text('Delete "${label.name}"? This removes it from all documents.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LabelService.instance.deleteLabel(label.name);
    }
  }
}
```

Add a navigation link in settings screen (find the settings screen and add a ListTile).

Add a route in the app router.

**Step 2: Run the app to test**

Run: `make run-web`
Verify: Navigate to settings → Manage Labels, rename/recolor/delete labels.

**Step 3: Commit**

```bash
git add lib/screens/label_management_screen.dart lib/screens/settings_screen.dart lib/router/app_router.dart
git commit -m "feat: add label management screen"
```

---

### Task 10: Schedule Sidecar Write on Label Changes

**Files:**
- Modify: `lib/services/label_service.dart`

**Step 1: Write the implementation**

When a label is added/removed from a document, schedule a sidecar write via `SyncManager` (same pattern as `SetListService._scheduleSyncWrite`).

Add to `LabelService`:

```dart
import 'sync_service.dart';
import 'database_service.dart';
import 'file_watcher_service.dart';
```

Add a private method:

```dart
Future<void> _scheduleSidecarWrite(int documentId) async {
  final doc = await _database.getDocument(documentId);
  if (doc == null || doc.filePath.startsWith('web://')) return;

  SyncManager.instance.scheduleAnnotationWrite(
    db: _database,
    documentId: documentId,
    scoreFilePath: doc.filePath,
  );
}
```

Call `_scheduleSidecarWrite(documentId)` after:
- `addLabelToDocument`
- `removeLabelFromDocument`
- `addLabelToDocuments` (for each doc)

**Step 2: Run all tests**

Run: `flutter test`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add lib/services/label_service.dart
git commit -m "feat: schedule sidecar write on label changes"
```

---

### Task 11: Final Integration Test and Cleanup

**Step 1: Run all tests**

Run: `flutter test`
Expected: ALL PASS

**Step 2: Run the app and test end-to-end**

Run: `make run-web`

Test checklist:
- [ ] Labels auto-created from subdirectory names during library scan
- [ ] Filter bar shows all labels, chips toggle, AND filtering works
- [ ] Multi-select → Label action → dialog → apply works
- [ ] Document viewer shows labels, add/remove works
- [ ] Manage Labels screen: rename, recolor, delete
- [ ] Sidecar `.feuillet.json` includes labels after label changes
- [ ] Importing a sidecar with labels creates labels + associations

**Step 3: Run analyze and format**

Run: `make analyze && make format`
Fix any issues.

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup for document labels feature"
```
