import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// ignore_for_file: unused_element
part 'database.g.dart';

// Documents table - stores PDF metadata
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text()();
  BlobColumn get pdfBytes =>
      blob().nullable()(); // For web platform - stores PDF bytes
  DateTimeColumn get dateAdded => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastOpened => dateTime().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  IntColumn get fileSize => integer()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
}

// Document settings - stores per-document viewing preferences
class DocumentSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  RealColumn get zoomLevel => real().withDefault(const Constant(1.0))();
  RealColumn get brightness => real().withDefault(const Constant(0.0))();
  RealColumn get contrast => real().withDefault(const Constant(1.0))();
  IntColumn get currentPage => integer().withDefault(const Constant(0))();
  TextColumn get viewMode => text().withDefault(const Constant('single'))();
  DateTimeColumn get lastUpdated =>
      dateTime().withDefault(currentDateAndTime)();
}

// Annotation layers - supports multiple layers per document
class AnnotationLayers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get orderIndex => integer()();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Annotations - stores drawing data for each layer
class Annotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get layerId => integer().references(
    AnnotationLayers,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get pageNumber => integer()();
  TextColumn get type =>
      text()(); // 'pen', 'highlighter', 'eraser', 'text', etc.
  TextColumn get data =>
      text()(); // JSON-encoded drawing data (points, color, thickness)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get modifiedAt => dateTime().withDefault(currentDateAndTime)();
}

// Set lists - collections of documents for performances
class SetLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get modifiedAt => dateTime().withDefault(currentDateAndTime)();
}

// Set list items - documents in a set list with ordering
class SetListItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get setListId =>
      integer().references(SetLists, #id, onDelete: KeyAction.cascade)();
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get orderIndex => integer()();
  TextColumn get notes => text().nullable()();
}

// App-wide settings stored as key-value pairs
class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().withLength(min: 1, max: 100).unique()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Database implementation
@DriftDatabase(
  tables: [
    Documents,
    DocumentSettings,
    AnnotationLayers,
    Annotations,
    SetLists,
    SetListItems,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor (e.g., in-memory database)
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add pdfBytes column for web platform support
          await m.addColumn(documents, documents.pdfBytes);
        }
        if (from < 3) {
          // Add viewMode column for two-page view support
          await m.addColumn(documentSettings, documentSettings.viewMode);
        }
        if (from < 4) {
          // Add app settings table for configurable PDF directory
          await m.createTable(appSettings);
        }
      },
      beforeOpen: (details) async {
        // Enable WAL mode for better concurrent access (Syncthing compatibility)
        await customStatement('PRAGMA journal_mode=WAL;');
        // Enable foreign key constraints
        await customStatement('PRAGMA foreign_keys=ON;');
      },
    );
  }

  // Document operations
  Future<int> insertDocument(DocumentsCompanion document) {
    return into(documents).insert(document);
  }

  Future<List<Document>> getAllDocuments() {
    return select(documents).get();
  }

  Future<Document?> getDocument(int id) {
    return (select(documents)..where((d) => d.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateDocument(Document document) {
    return update(documents).replace(document);
  }

  Future<void> deleteDocument(int id) {
    return (delete(documents)..where((d) => d.id.equals(id))).go();
  }

  Stream<List<Document>> watchAllDocuments() {
    return select(documents).watch();
  }

  // Document settings operations
  Future<DocumentSetting?> getDocumentSettings(int documentId) async {
    final results =
        await (select(documentSettings)
              ..where((s) => s.documentId.equals(documentId))
              ..limit(1))
            .get();
    return results.isEmpty ? null : results.first;
  }

  Future<int> insertOrUpdateDocumentSettings(
    DocumentSettingsCompanion settings,
  ) async {
    // Check if settings exist for this document
    final docId = settings.documentId.value;
    final existing = await getDocumentSettings(docId);

    if (existing != null) {
      // Update existing settings
      await (update(
        documentSettings,
      )..where((s) => s.documentId.equals(docId))).write(settings);
      return existing.id;
    } else {
      // Insert new settings
      return into(documentSettings).insert(settings);
    }
  }

  // Annotation layer operations
  Future<int> insertAnnotationLayer(AnnotationLayersCompanion layer) {
    return into(annotationLayers).insert(layer);
  }

  Future<List<AnnotationLayer>> getAnnotationLayers(int documentId) {
    return (select(annotationLayers)
          ..where((l) => l.documentId.equals(documentId))
          ..orderBy([(l) => OrderingTerm.asc(l.orderIndex)]))
        .get();
  }

  Future<void> updateAnnotationLayer(AnnotationLayer layer) {
    return update(annotationLayers).replace(layer);
  }

  Future<void> deleteAnnotationLayer(int id) {
    return (delete(annotationLayers)..where((l) => l.id.equals(id))).go();
  }

  // Annotation operations
  Future<int> insertAnnotation(AnnotationsCompanion annotation) {
    return into(annotations).insert(annotation);
  }

  Future<List<Annotation>> getAnnotations(int layerId, int pageNumber) {
    return (select(annotations)..where(
          (a) => a.layerId.equals(layerId) & a.pageNumber.equals(pageNumber),
        ))
        .get();
  }

  Future<void> deleteAnnotation(int id) {
    return (delete(annotations)..where((a) => a.id.equals(id))).go();
  }

  // Set list operations
  Future<int> insertSetList(SetListsCompanion setList) {
    return into(setLists).insert(setList);
  }

  Future<List<SetList>> getAllSetLists() {
    return select(setLists).get();
  }

  Future<SetList?> getSetList(int id) {
    return (select(setLists)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateSetList(SetList setList) {
    return update(setLists).replace(setList);
  }

  Future<void> deleteSetList(int id) {
    return (delete(setLists)..where((s) => s.id.equals(id))).go();
  }

  Stream<List<SetList>> watchAllSetLists() {
    return select(setLists).watch();
  }

  // Set list item operations
  Future<int> insertSetListItem(SetListItemsCompanion item) {
    return into(setListItems).insert(item);
  }

  Future<List<SetListItem>> getSetListItems(int setListId) {
    return (select(setListItems)
          ..where((i) => i.setListId.equals(setListId))
          ..orderBy([(i) => OrderingTerm.asc(i.orderIndex)]))
        .get();
  }

  Future<void> deleteSetListItem(int id) {
    return (delete(setListItems)..where((i) => i.id.equals(id))).go();
  }

  // Join query to get documents in a set list
  Future<List<Document>> getDocumentsInSetList(int setListId) async {
    final items = await getSetListItems(setListId);
    final docIds = items.map((i) => i.documentId).toList();

    if (docIds.isEmpty) return [];

    return (select(documents)..where((d) => d.id.isIn(docIds))).get();
  }

  // App settings operations
  Future<String?> getAppSetting(String key) async {
    final result =
        await (select(appSettings)
              ..where((s) => s.key.equals(key))
              ..limit(1))
            .getSingleOrNull();
    return result?.value;
  }

  Future<void> setAppSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteAppSetting(String key) async {
    await (delete(appSettings)..where((s) => s.key.equals(key))).go();
  }
}

// Connection configuration with WAL mode for better Syncthing compatibility
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'open_score_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
    native: DriftNativeOptions(shareAcrossIsolates: false),
  );
}
