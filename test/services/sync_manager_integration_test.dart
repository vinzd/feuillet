import 'dart:async';
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
    tempDir = await Directory.systemTemp.createTemp('sync_mgr_test_');
  });

  tearDown(() async {
    SyncManager.resetInstance();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('SyncManager suppression', () {
    test('suppressPath prevents processing for duration, then expires', () {
      final mgr = SyncManager.instance;

      mgr.suppressPath('/docs/Test.feuillet.json');
      expect(mgr.isSuppressed('/docs/Test.feuillet.json'), isTrue);
    });

    test('different paths are not suppressed', () {
      final mgr = SyncManager.instance;

      mgr.suppressPath('/docs/A.feuillet.json');
      expect(mgr.isSuppressed('/docs/B.feuillet.json'), isFalse);
    });

    test('isSuppressed returns false for unknown paths', () {
      final mgr = SyncManager.instance;
      expect(mgr.isSuppressed('/never/seen.json'), isFalse);
    });

    test('suppression expires after duration', () async {
      final mgr = SyncManager.instance;
      // Override internal suppression with a very short duration for testing.
      mgr.suppressPathWithDuration(
        '/docs/Expire.feuillet.json',
        const Duration(milliseconds: 50),
      );
      expect(mgr.isSuppressed('/docs/Expire.feuillet.json'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(mgr.isSuppressed('/docs/Expire.feuillet.json'), isFalse);
    });
  });

  group('SyncManager reconciliation', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    /// Helper to insert a document pointing at a file in tempDir.
    Future<int> insertDoc(String fileName) async {
      return db.insertDocument(
        DocumentsCompanion(
          name: Value(fileName),
          filePath: Value('${tempDir.path}/$fileName'),
          lastModified: Value(DateTime.utc(2026, 1, 1)),
          fileSize: const Value(1000),
          pageCount: const Value(3),
        ),
      );
    }

    /// Helper: build a minimal sidecar JSON string.
    String sidecarJson() {
      return jsonEncode({
        'version': 1,
        'modifiedAt': '2026-03-03T00:00:00.000Z',
        'layers': [
          {
            'name': 'Layer 1',
            'isVisible': true,
            'orderIndex': 0,
            'annotations': [
              {
                'pageNumber': 0,
                'strokes': [
                  {
                    'points': [
                      {'x': 10.0, 'y': 20.0},
                    ],
                    'color': 0xFFFF0000,
                    'thickness': 3.0,
                    'type': 'AnnotationType.pen',
                  },
                ],
              },
            ],
          },
        ],
      });
    }

    /// Helper: annotation stroke JSON for the DB.
    String strokeJson() {
      return jsonEncode({
        'points': [
          {'x': 10.0, 'y': 20.0},
        ],
        'color': 0xFFFF0000,
        'thickness': 3.0,
        'type': 'pen',
      });
    }

    test('imports sidecar files from disk on reconciliation', () async {
      // Create a score file and its sidecar on disk.
      final scoreFile = File('${tempDir.path}/Bach.pdf');
      await scoreFile.writeAsString('fake pdf');

      final sidecarFile = File('${tempDir.path}/Bach.feuillet.json');
      await sidecarFile.writeAsString(sidecarJson());

      // Insert matching document in DB.
      final docId = await insertDoc('Bach.pdf');

      final mgr = SyncManager.instance;
      await mgr.reconcileOnStartup(db: db, pdfDirectoryPath: tempDir.path);

      // Verify annotations were imported.
      final layers = await db.getAnnotationLayers(docId);
      expect(layers.length, 1);
      expect(layers[0].name, 'Layer 1');
    });

    test('imports set list files from disk on reconciliation', () async {
      // Create a document for the set list to reference.
      final docId = await insertDoc('Bach.pdf');

      // Create the setlists directory and file.
      final setListsDir = Directory('${tempDir.path}/setlists');
      await setListsDir.create();
      final setListFile = File('${tempDir.path}/setlists/Concert.setlist.json');
      await setListFile.writeAsString(
        jsonEncode({
          'version': 1,
          'modifiedAt': '2026-03-03T00:00:00.000Z',
          'name': 'Concert',
          'description': 'My concert',
          'items': [
            {'documentPath': 'Bach.pdf', 'orderIndex': 0},
          ],
        }),
      );

      final mgr = SyncManager.instance;
      await mgr.reconcileOnStartup(db: db, pdfDirectoryPath: tempDir.path);

      // Verify set list was imported.
      final setLists = await db.getAllSetLists();
      expect(setLists.length, 1);
      expect(setLists[0].name, 'Concert');
    });

    test(
      'exports annotations that only exist in DB (no sidecar on disk)',
      () async {
        // Insert document with annotations but NO sidecar on disk.
        final docId = await insertDoc('Mozart.pdf');

        // Create the actual score file so the path is "valid".
        final scoreFile = File('${tempDir.path}/Mozart.pdf');
        await scoreFile.writeAsString('fake pdf');

        // Add an annotation layer + stroke in DB.
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

        // Verify no sidecar exists yet.
        final sidecarPath = '${tempDir.path}/Mozart.feuillet.json';
        expect(await File(sidecarPath).exists(), isFalse);

        final mgr = SyncManager.instance;
        await mgr.reconcileOnStartup(db: db, pdfDirectoryPath: tempDir.path);

        // Verify sidecar was exported.
        expect(await File(sidecarPath).exists(), isTrue);

        final content = await File(sidecarPath).readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['version'], 1);
        expect((json['layers'] as List).length, 1);
      },
    );

    test('skips web:// paths during reconciliation', () async {
      // Insert a web document - should be skipped.
      await db.insertDocument(
        DocumentsCompanion(
          name: const Value('Web.pdf'),
          filePath: const Value('web://Web.pdf'),
          lastModified: Value(DateTime.utc(2026, 1, 1)),
          fileSize: const Value(500),
          pageCount: const Value(1),
        ),
      );

      // Should not throw even though web:// path doesn't exist on disk.
      final mgr = SyncManager.instance;
      await mgr.reconcileOnStartup(db: db, pdfDirectoryPath: tempDir.path);
    });
  });
}
