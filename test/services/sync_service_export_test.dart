import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
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

  /// Helper to insert a test document and return its id.
  Future<int> insertTestDocument(AppDatabase db) async {
    return db.insertDocument(
      DocumentsCompanion(
        name: const Value('Test.pdf'),
        filePath: const Value('/docs/Test.pdf'),
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

  group('buildAnnotationSidecar', () {
    test(
      'builds sidecar from document with one layer and one annotation',
      () async {
        final docId = await insertTestDocument(db);

        final layerId = await db.insertAnnotationLayer(
          AnnotationLayersCompanion(
            documentId: Value(docId),
            name: const Value('Layer 1'),
            orderIndex: const Value(0),
            isVisible: const Value(true),
          ),
        );

        await db.insertAnnotation(
          AnnotationsCompanion(
            layerId: Value(layerId),
            pageNumber: const Value(0),
            type: const Value('pen'),
            data: Value(strokeJson()),
          ),
        );

        final sidecar = await buildAnnotationSidecar(db, docId);

        expect(sidecar, isNotNull);
        expect(sidecar!.version, 1);
        expect(sidecar.layers.length, 1);
        expect(sidecar.layers[0].name, 'Layer 1');
        expect(sidecar.layers[0].isVisible, true);
        expect(sidecar.layers[0].orderIndex, 0);
        expect(sidecar.layers[0].annotations.length, 1);
        expect(sidecar.layers[0].annotations[0].pageNumber, 0);
        expect(sidecar.layers[0].annotations[0].strokes.length, 1);
        expect(sidecar.layers[0].annotations[0].strokes[0].thickness, 3.0);
        expect(
          sidecar.layers[0].annotations[0].strokes[0].color.toARGB32(),
          0xFFFF0000,
        );
      },
    );

    test('returns null when document has no layers', () async {
      final docId = await insertTestDocument(db);

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNull);
    });

    test('returns null when document has layers but no annotations', () async {
      final docId = await insertTestDocument(db);

      await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(docId),
          name: const Value('Empty Layer'),
          orderIndex: const Value(0),
          isVisible: const Value(true),
        ),
      );

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNull);
    });

    test(
      'handles multiple layers with annotations on different pages',
      () async {
        final docId = await insertTestDocument(db);

        final layer1Id = await db.insertAnnotationLayer(
          AnnotationLayersCompanion(
            documentId: Value(docId),
            name: const Value('Pen Notes'),
            orderIndex: const Value(0),
            isVisible: const Value(true),
          ),
        );

        final layer2Id = await db.insertAnnotationLayer(
          AnnotationLayersCompanion(
            documentId: Value(docId),
            name: const Value('Highlights'),
            orderIndex: const Value(1),
            isVisible: const Value(false),
          ),
        );

        // Layer 1: annotations on pages 0 and 2
        await db.insertAnnotation(
          AnnotationsCompanion(
            layerId: Value(layer1Id),
            pageNumber: const Value(0),
            type: const Value('pen'),
            data: Value(strokeJson(x: 1, y: 2)),
          ),
        );
        await db.insertAnnotation(
          AnnotationsCompanion(
            layerId: Value(layer1Id),
            pageNumber: const Value(2),
            type: const Value('pen'),
            data: Value(strokeJson(x: 3, y: 4)),
          ),
        );

        // Layer 2: annotation on page 1
        await db.insertAnnotation(
          AnnotationsCompanion(
            layerId: Value(layer2Id),
            pageNumber: const Value(1),
            type: const Value('highlighter'),
            data: Value(strokeJson(x: 5, y: 6, type: 'highlighter')),
          ),
        );

        final sidecar = await buildAnnotationSidecar(db, docId);

        expect(sidecar, isNotNull);
        expect(sidecar!.version, 1);
        expect(sidecar.layers.length, 2);

        // Layer 1 assertions
        final l1 = sidecar.layers[0];
        expect(l1.name, 'Pen Notes');
        expect(l1.isVisible, true);
        expect(l1.orderIndex, 0);
        expect(l1.annotations.length, 2);
        // Pages should be sorted by page number
        expect(l1.annotations[0].pageNumber, 0);
        expect(l1.annotations[1].pageNumber, 2);

        // Layer 2 assertions
        final l2 = sidecar.layers[1];
        expect(l2.name, 'Highlights');
        expect(l2.isVisible, false);
        expect(l2.orderIndex, 1);
        expect(l2.annotations.length, 1);
        expect(l2.annotations[0].pageNumber, 1);
        expect(l2.annotations[0].strokes.length, 1);
      },
    );

    test('groups multiple annotations on the same page', () async {
      final docId = await insertTestDocument(db);

      final layerId = await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(docId),
          name: const Value('Layer 1'),
          orderIndex: const Value(0),
          isVisible: const Value(true),
        ),
      );

      // Two annotations on the same page
      await db.insertAnnotation(
        AnnotationsCompanion(
          layerId: Value(layerId),
          pageNumber: const Value(0),
          type: const Value('pen'),
          data: Value(strokeJson(x: 1, y: 1)),
        ),
      );
      await db.insertAnnotation(
        AnnotationsCompanion(
          layerId: Value(layerId),
          pageNumber: const Value(0),
          type: const Value('highlighter'),
          data: Value(strokeJson(x: 2, y: 2, type: 'highlighter')),
        ),
      );

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNotNull);
      expect(sidecar!.layers[0].annotations.length, 1); // One page group
      expect(sidecar.layers[0].annotations[0].strokes.length, 2); // Two strokes
    });
  });
}
