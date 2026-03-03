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
  Future<int> insertTestDocument() async {
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

  group('importAnnotationSidecar', () {
    test('creates layers and annotations from sidecar', () async {
      final docId = await insertTestDocument();

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
                    points: [const Offset(10, 20), const Offset(30, 40)],
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
      expect(layers[0].isVisible, true);
      expect(layers[0].orderIndex, 0);

      // Check annotations exist for the layer.
      final annotations = await (db.select(
        db.annotations,
      )..where((a) => a.layerId.equals(layers[0].id))).get();
      expect(annotations.length, 1);
      expect(annotations[0].pageNumber, 0);
      expect(annotations[0].type, 'pen');

      // Verify the stroke data round-trips.
      final data = jsonDecode(annotations[0].data) as Map<String, dynamic>;
      expect((data['points'] as List).length, 2);
      expect(data['thickness'], 3.0);
    });

    test('replaces existing annotations on reimport', () async {
      final docId = await insertTestDocument();

      // First import.
      final sidecar1 = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [
          SidecarLayer(
            name: 'Old Layer',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 0,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(1, 1)],
                    color: Colors.blue,
                    thickness: 2.0,
                    type: AnnotationType.pen,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await importAnnotationSidecar(db, docId, sidecar1);

      // Second import with different data.
      final sidecar2 = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 4),
        layers: [
          SidecarLayer(
            name: 'New Layer',
            isVisible: false,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 1,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(50, 60)],
                    color: Colors.green,
                    thickness: 5.0,
                    type: AnnotationType.highlighter,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await importAnnotationSidecar(db, docId, sidecar2);

      // Old layer should be gone, only new layer exists.
      final layers = await db.getAnnotationLayers(docId);
      expect(layers.length, 1);
      expect(layers[0].name, 'New Layer');
      expect(layers[0].isVisible, false);

      final annotations = await (db.select(
        db.annotations,
      )..where((a) => a.layerId.equals(layers[0].id))).get();
      expect(annotations.length, 1);
      expect(annotations[0].pageNumber, 1);
      expect(annotations[0].type, 'highlighter');
    });

    test('handles sidecar with multiple layers and pages', () async {
      final docId = await insertTestDocument();

      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [
          SidecarLayer(
            name: 'Layer A',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 0,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(1, 2)],
                    color: Colors.red,
                    thickness: 1.0,
                    type: AnnotationType.pen,
                  ),
                  DrawingStroke(
                    points: [const Offset(3, 4)],
                    color: Colors.blue,
                    thickness: 2.0,
                    type: AnnotationType.highlighter,
                  ),
                ],
              ),
              SidecarPageAnnotations(
                pageNumber: 1,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(5, 6)],
                    color: Colors.green,
                    thickness: 3.0,
                    type: AnnotationType.pen,
                  ),
                ],
              ),
            ],
          ),
          SidecarLayer(
            name: 'Layer B',
            isVisible: false,
            orderIndex: 1,
            annotations: [
              SidecarPageAnnotations(
                pageNumber: 2,
                strokes: [
                  DrawingStroke(
                    points: [const Offset(7, 8)],
                    color: Colors.black,
                    thickness: 4.0,
                    type: AnnotationType.eraser,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await importAnnotationSidecar(db, docId, sidecar);

      final layers = await db.getAnnotationLayers(docId);
      expect(layers.length, 2);

      // Sort by orderIndex for predictable assertions.
      layers.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(layers[0].name, 'Layer A');
      expect(layers[1].name, 'Layer B');

      // Layer A should have 3 annotation rows (2 strokes on page 0, 1 on page 1).
      final annotationsA = await (db.select(
        db.annotations,
      )..where((a) => a.layerId.equals(layers[0].id))).get();
      expect(annotationsA.length, 3);

      // Layer B should have 1 annotation row.
      final annotationsB = await (db.select(
        db.annotations,
      )..where((a) => a.layerId.equals(layers[1].id))).get();
      expect(annotationsB.length, 1);
      expect(annotationsB[0].pageNumber, 2);
      expect(annotationsB[0].type, 'eraser');
    });

    test('handles empty sidecar by deleting existing annotations', () async {
      final docId = await insertTestDocument();

      // Pre-populate with a layer and annotation.
      final layerId = await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(docId),
          name: const Value('Existing'),
          orderIndex: const Value(0),
          isVisible: const Value(true),
        ),
      );
      await db.insertAnnotation(
        AnnotationsCompanion(
          layerId: Value(layerId),
          pageNumber: const Value(0),
          type: const Value('pen'),
          data: Value(
            jsonEncode({
              'points': [
                {'x': 1.0, 'y': 2.0},
              ],
              'color': 0xFFFF0000,
              'thickness': 3.0,
              'type': 'pen',
            }),
          ),
        ),
      );

      // Import empty sidecar.
      final emptySidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [],
      );
      await importAnnotationSidecar(db, docId, emptySidecar);

      // All layers should be gone.
      final layers = await db.getAnnotationLayers(docId);
      expect(layers, isEmpty);
    });
  });
}
