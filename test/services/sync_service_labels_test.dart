import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  group('SidecarLabel', () {
    test('toJson with color', () {
      final label = SidecarLabel(name: 'Favorite', color: 0xFFFF0000);
      final json = label.toJson();

      expect(json['name'], 'Favorite');
      expect(json['color'], 0xFFFF0000);
    });

    test('toJson without color omits color key', () {
      final label = SidecarLabel(name: 'Practice');
      final json = label.toJson();

      expect(json['name'], 'Practice');
      expect(json.containsKey('color'), isFalse);
    });

    test('fromJson with color', () {
      final label = SidecarLabel.fromJson({
        'name': 'Concert',
        'color': 0xFF00FF00,
      });

      expect(label.name, 'Concert');
      expect(label.color, 0xFF00FF00);
    });

    test('fromJson without color', () {
      final label = SidecarLabel.fromJson({'name': 'Warm-up'});

      expect(label.name, 'Warm-up');
      expect(label.color, isNull);
    });

    test('roundtrip preserves data', () {
      final original = SidecarLabel(name: 'Test', color: 0xFF123456);
      final restored = SidecarLabel.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.color, original.color);
    });
  });

  group('AnnotationSidecar with labels', () {
    test('toJson includes labels when present', () {
      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.utc(2026, 3, 1),
        layers: [],
        labels: [
          SidecarLabel(name: 'Favorite', color: 0xFFFF0000),
          SidecarLabel(name: 'Practice'),
        ],
      );
      final json = sidecar.toJson();

      expect(json['labels'], isA<List>());
      final labels = json['labels'] as List;
      expect(labels.length, 2);
      expect((labels[0] as Map)['name'], 'Favorite');
      expect((labels[0] as Map)['color'], 0xFFFF0000);
      expect((labels[1] as Map)['name'], 'Practice');
      expect((labels[1] as Map).containsKey('color'), isFalse);
    });

    test('toJson omits labels key when empty', () {
      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 1),
        layers: [],
      );
      final json = sidecar.toJson();

      expect(json.containsKey('labels'), isFalse);
    });

    test('fromJson reads labels', () {
      final json = {
        'version': 2,
        'modifiedAt': '2026-03-01T00:00:00.000Z',
        'layers': <Map<String, dynamic>>[],
        'labels': [
          {'name': 'Concert', 'color': 0xFF0000FF},
        ],
      };
      final sidecar = AnnotationSidecar.fromJson(json);

      expect(sidecar.labels.length, 1);
      expect(sidecar.labels[0].name, 'Concert');
      expect(sidecar.labels[0].color, 0xFF0000FF);
    });

    test('fromJson handles missing labels field (v1 backward compat)', () {
      final json = {
        'version': 1,
        'modifiedAt': '2026-03-01T00:00:00.000Z',
        'layers': <Map<String, dynamic>>[],
      };
      final sidecar = AnnotationSidecar.fromJson(json);

      expect(sidecar.labels, isEmpty);
    });

    test('roundtrip preserves labels', () {
      final original = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.utc(2026, 3, 1),
        layers: [],
        labels: [
          SidecarLabel(name: 'A', color: 0xFF111111),
          SidecarLabel(name: 'B'),
        ],
      );
      final restored = AnnotationSidecar.fromJson(original.toJson());

      expect(restored.labels.length, 2);
      expect(restored.labels[0].name, 'A');
      expect(restored.labels[0].color, 0xFF111111);
      expect(restored.labels[1].name, 'B');
      expect(restored.labels[1].color, isNull);
    });
  });

  group('buildAnnotationSidecar with labels', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

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

    test('includes document labels', () async {
      final docId = await insertTestDocument();

      // Add a label and associate it.
      await db.insertLabel(
        LabelsCompanion(
          name: const Value('Concert'),
          color: const Value(0xFFFF0000),
        ),
      );
      await db.addLabelToDocument(docId, 'Concert');

      // Also add an annotation layer with a stroke so we get a non-null result.
      final layerId = await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(docId),
          name: const Value('Layer 1'),
          orderIndex: const Value(0),
          isVisible: const Value(true),
        ),
      );
      final stroke = DrawingStroke(
        points: [const Offset(0, 0)],
        color: Colors.black,
        thickness: 1.0,
        type: AnnotationType.pen,
      );
      await db.insertAnnotation(
        AnnotationsCompanion(
          layerId: Value(layerId),
          pageNumber: const Value(0),
          type: const Value('pen'),
          data: Value(jsonEncode(stroke.toJson())),
        ),
      );

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNotNull);
      expect(sidecar!.labels.length, 1);
      expect(sidecar.labels[0].name, 'Concert');
      expect(sidecar.labels[0].color, 0xFFFF0000);
      expect(sidecar.version, 2);
    });

    test(
      'returns non-null when document has labels but no annotations',
      () async {
        final docId = await insertTestDocument();

        // Add labels only, no annotation layers.
        await db.insertLabel(
          LabelsCompanion(
            name: const Value('Practice'),
            color: const Value(null),
          ),
        );
        await db.addLabelToDocument(docId, 'Practice');

        final sidecar = await buildAnnotationSidecar(db, docId);

        expect(sidecar, isNotNull);
        expect(sidecar!.layers, isEmpty);
        expect(sidecar.labels.length, 1);
        expect(sidecar.labels[0].name, 'Practice');
        expect(sidecar.version, 2);
      },
    );

    test('returns null when no annotations and no labels', () async {
      final docId = await insertTestDocument();

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNull);
    });

    test('version is 1 when annotations exist but no labels', () async {
      final docId = await insertTestDocument();

      final layerId = await db.insertAnnotationLayer(
        AnnotationLayersCompanion(
          documentId: Value(docId),
          name: const Value('Layer 1'),
          orderIndex: const Value(0),
          isVisible: const Value(true),
        ),
      );
      final stroke = DrawingStroke(
        points: [const Offset(0, 0)],
        color: Colors.black,
        thickness: 1.0,
        type: AnnotationType.pen,
      );
      await db.insertAnnotation(
        AnnotationsCompanion(
          layerId: Value(layerId),
          pageNumber: const Value(0),
          type: const Value('pen'),
          data: Value(jsonEncode(stroke.toJson())),
        ),
      );

      final sidecar = await buildAnnotationSidecar(db, docId);

      expect(sidecar, isNotNull);
      expect(sidecar!.version, 1);
      expect(sidecar.labels, isEmpty);
    });
  });

  group('importAnnotationSidecar with labels', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

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

    test('creates labels and associations from sidecar', () async {
      final docId = await insertTestDocument();

      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [],
        labels: [
          SidecarLabel(name: 'Concert', color: 0xFFFF0000),
          SidecarLabel(name: 'Practice'),
        ],
      );

      await importAnnotationSidecar(db, docId, sidecar);

      // Check labels were created.
      final concert = await db.getLabel('Concert');
      expect(concert, isNotNull);
      expect(concert!.color, 0xFFFF0000);

      final practice = await db.getLabel('Practice');
      expect(practice, isNotNull);
      expect(practice!.color, isNull);

      // Check document-label associations.
      final docLabels = await db.getLabelsForDocument(docId);
      expect(docLabels.length, 2);
      final names = docLabels.map((l) => l.name).toSet();
      expect(names, containsAll(['Concert', 'Practice']));
    });

    test('does NOT overwrite existing label color', () async {
      final docId = await insertTestDocument();

      // Pre-create a label with a specific color.
      await db.insertLabel(
        LabelsCompanion(
          name: const Value('Concert'),
          color: const Value(0xFF00FF00),
        ),
      );

      // Import sidecar with same label but different color.
      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [],
        labels: [SidecarLabel(name: 'Concert', color: 0xFFFF0000)],
      );

      await importAnnotationSidecar(db, docId, sidecar);

      // Color should remain the original local color.
      final label = await db.getLabel('Concert');
      expect(label, isNotNull);
      expect(label!.color, 0xFF00FF00);

      // But the association should exist.
      final docLabels = await db.getLabelsForDocument(docId);
      expect(docLabels.length, 1);
      expect(docLabels[0].name, 'Concert');
    });

    test('imports labels alongside annotation layers', () async {
      final docId = await insertTestDocument();

      final sidecar = AnnotationSidecar(
        version: 2,
        modifiedAt: DateTime.utc(2026, 3, 3),
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
        labels: [SidecarLabel(name: 'Favorite', color: 0xFF0000FF)],
      );

      await importAnnotationSidecar(db, docId, sidecar);

      // Verify annotations imported.
      final layers = await db.getAnnotationLayers(docId);
      expect(layers.length, 1);
      expect(layers[0].name, 'Main');

      // Verify labels imported.
      final docLabels = await db.getLabelsForDocument(docId);
      expect(docLabels.length, 1);
      expect(docLabels[0].name, 'Favorite');
    });

    test('handles sidecar with no labels (v1 compat)', () async {
      final docId = await insertTestDocument();

      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2026, 3, 3),
        layers: [],
      );

      await importAnnotationSidecar(db, docId, sidecar);

      final docLabels = await db.getLabelsForDocument(docId);
      expect(docLabels, isEmpty);
    });
  });
}
