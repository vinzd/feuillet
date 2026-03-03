import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('writeAnnotationSidecarToDisk', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    /// Helper to insert a test document and return its id.
    Future<int> insertTestDocument(String filePath) async {
      return db.insertDocument(
        DocumentsCompanion(
          name: Value(filePath.split('/').last),
          filePath: Value(filePath),
          lastModified: Value(DateTime.utc(2026, 1, 1)),
          fileSize: const Value(1000),
          pageCount: const Value(3),
        ),
      );
    }

    /// Helper to create a JSON-encoded DrawingStroke.
    String strokeJson({
      double x = 10.0,
      double y = 20.0,
      int color = 0xFFFF0000,
      double thickness = 3.0,
      String type = 'pen',
    }) {
      return jsonEncode({
        'points': [
          {'x': x, 'y': y},
        ],
        'color': color,
        'thickness': thickness,
        'type': type,
      });
    }

    test('creates .feuillet.json file with correct content', () async {
      final scoreFilePath = '${tempDir.path}/Bach - Suite 1.pdf';

      // Create a dummy score file so the directory exists.
      await File(scoreFilePath).writeAsString('dummy');

      final docId = await insertTestDocument(scoreFilePath);

      // Add a layer with an annotation.
      final layerId = await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(docId),
          name: const Value('Main'),
          orderIndex: const Value(0),
          isVisible: const Value(true),
        ),
      );
      await db.insertAnnotation(
        AnnotationsCompanion(
          layerId: Value(layerId),
          pageNumber: const Value(0),
          data: Value(strokeJson()),
          type: const Value('pen'),
        ),
      );

      await writeAnnotationSidecarToDisk(
        db: db,
        documentId: docId,
        scoreFilePath: scoreFilePath,
      );

      final sidecarPath = '${tempDir.path}/Bach - Suite 1.feuillet.json';
      final sidecarFile = File(sidecarPath);
      expect(await sidecarFile.exists(), isTrue);

      final content = await sidecarFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['layers'], isA<List>());
      expect((json['layers'] as List).length, 1);

      // Verify it's pretty-printed (contains newlines and indentation).
      expect(content.contains('\n'), isTrue);
      expect(content.contains('  '), isTrue);
    });

    test('deletes sidecar when no annotations exist', () async {
      final scoreFilePath = '${tempDir.path}/Empty.pdf';
      await File(scoreFilePath).writeAsString('dummy');

      final docId = await insertTestDocument(scoreFilePath);

      // Pre-create a sidecar file to verify it gets deleted.
      final sidecarPath = '${tempDir.path}/Empty.feuillet.json';
      await File(sidecarPath).writeAsString('{"old": true}');
      expect(await File(sidecarPath).exists(), isTrue);

      await writeAnnotationSidecarToDisk(
        db: db,
        documentId: docId,
        scoreFilePath: scoreFilePath,
      );

      expect(await File(sidecarPath).exists(), isFalse);
    });
  });

  group('readAnnotationSidecarFromDisk', () {
    test('parses existing file', () async {
      final scoreFilePath = '${tempDir.path}/Score.pdf';
      final sidecarPath = '${tempDir.path}/Score.feuillet.json';

      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3),
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

      const encoder = JsonEncoder.withIndent('  ');
      await File(sidecarPath).writeAsString(encoder.convert(sidecar.toJson()));

      final result = await readAnnotationSidecarFromDisk(scoreFilePath);

      expect(result, isNotNull);
      expect(result!.version, 1);
      expect(result.layers.length, 1);
      expect(result.layers[0].name, 'Layer 1');
      expect(result.layers[0].annotations[0].strokes.length, 1);
    });

    test('returns null for missing file', () async {
      final scoreFilePath = '${tempDir.path}/DoesNotExist.pdf';

      final result = await readAnnotationSidecarFromDisk(scoreFilePath);

      expect(result, isNull);
    });

    test('returns null for invalid JSON', () async {
      final scoreFilePath = '${tempDir.path}/Bad.pdf';
      final sidecarPath = '${tempDir.path}/Bad.feuillet.json';
      await File(sidecarPath).writeAsString('not valid json {{{');

      final result = await readAnnotationSidecarFromDisk(scoreFilePath);

      expect(result, isNull);
    });
  });

  group('writeSetListFileToDisk', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('creates file in setlists/ subdirectory', () async {
      final pdfDir = tempDir.path;

      // Insert a document and set list.
      final docId = await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Bach.pdf'),
          filePath: Value('$pdfDir/Bach.pdf'),
          lastModified: Value(DateTime.utc(2026, 1, 1)),
          fileSize: const Value(1000),
          pageCount: const Value(3),
        ),
      );

      final setListId = await db.insertSetList(
        SetListsCompanion(
          name: const Value('Concert'),
          description: const Value('Spring recital'),
          modifiedAt: Value(DateTime.utc(2026, 3, 1)),
        ),
      );

      await db.insertSetListItem(
        SetListItemsCompanion(
          setListId: Value(setListId),
          documentId: Value(docId),
          orderIndex: const Value(0),
          notes: const Value('opener'),
        ),
      );

      await writeSetListFileToDisk(
        db: db,
        setListId: setListId,
        pdfDirectoryPath: pdfDir,
      );

      final expectedPath = '${tempDir.path}/setlists/Concert.setlist.json';
      final file = File(expectedPath);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['name'], 'Concert');
      expect(json['description'], 'Spring recital');
      expect((json['items'] as List).length, 1);

      // Verify setlists/ directory was created.
      expect(await Directory('${tempDir.path}/setlists').exists(), isTrue);
    });
  });

  group('readSetListFileFromDisk', () {
    test('returns null for missing file', () async {
      final result = await readSetListFileFromDisk(
        '${tempDir.path}/setlists/Nope.setlist.json',
      );

      expect(result, isNull);
    });

    test('parses existing set list file', () async {
      final setListsDir = Directory('${tempDir.path}/setlists');
      await setListsDir.create();

      final setListFile = SetListFile(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 1),
        name: 'Recital',
        description: null,
        items: [
          SetListFileItem(
            documentPath: 'Bach.pdf',
            orderIndex: 0,
            notes: 'first piece',
          ),
        ],
      );

      const encoder = JsonEncoder.withIndent('  ');
      final filePath = '${setListsDir.path}/Recital.setlist.json';
      await File(filePath).writeAsString(encoder.convert(setListFile.toJson()));

      final result = await readSetListFileFromDisk(filePath);

      expect(result, isNotNull);
      expect(result!.name, 'Recital');
      expect(result.items.length, 1);
      expect(result.items[0].documentPath, 'Bach.pdf');
    });

    test('returns null for invalid JSON', () async {
      final setListsDir = Directory('${tempDir.path}/setlists');
      await setListsDir.create();

      final filePath = '${setListsDir.path}/Bad.setlist.json';
      await File(filePath).writeAsString('corrupt data');

      final result = await readSetListFileFromDisk(filePath);

      expect(result, isNull);
    });
  });

  group('deleteSetListFileFromDisk', () {
    test('removes existing file', () async {
      final setListsDir = Directory('${tempDir.path}/setlists');
      await setListsDir.create();

      final filePath = '${setListsDir.path}/Concert.setlist.json';
      await File(filePath).writeAsString('{"name":"Concert"}');
      expect(await File(filePath).exists(), isTrue);

      await deleteSetListFileFromDisk(
        setListName: 'Concert',
        pdfDirectoryPath: tempDir.path,
      );

      expect(await File(filePath).exists(), isFalse);
    });

    test('does nothing when file does not exist', () async {
      // Should not throw.
      await deleteSetListFileFromDisk(
        setListName: 'NonExistent',
        pdfDirectoryPath: tempDir.path,
      );
    });
  });
}
