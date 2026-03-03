import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/sync_service.dart';

void main() {
  group('sidecarFileName', () {
    test('replaces .pdf extension with .feuillet.json', () {
      expect(
        sidecarFileName('Bach - Suite 1.pdf'),
        'Bach - Suite 1.feuillet.json',
      );
    });

    test('replaces .jpg extension with .feuillet.json', () {
      expect(sidecarFileName('photo.jpg'), 'photo.feuillet.json');
    });

    test('replaces .jpeg extension with .feuillet.json', () {
      expect(sidecarFileName('photo.jpeg'), 'photo.feuillet.json');
    });

    test('replaces .png extension with .feuillet.json', () {
      expect(sidecarFileName('image.png'), 'image.feuillet.json');
    });

    test('handles files with multiple dots', () {
      expect(
        sidecarFileName('J.S. Bach - Suite.pdf'),
        'J.S. Bach - Suite.feuillet.json',
      );
    });

    test('handles files with multiple dots and spaces', () {
      expect(sidecarFileName('Op. 10 No. 3.pdf'), 'Op. 10 No. 3.feuillet.json');
    });

    test('handles full path', () {
      expect(
        sidecarFileName('/path/to/docs/Score.pdf'),
        '/path/to/docs/Score.feuillet.json',
      );
    });
  });

  group('SidecarPageAnnotations', () {
    test('toJson serializes correctly', () {
      final stroke = DrawingStroke(
        points: [const Offset(10, 20)],
        color: Colors.red,
        thickness: 3.0,
        type: AnnotationType.pen,
      );
      final page = SidecarPageAnnotations(pageNumber: 0, strokes: [stroke]);
      final json = page.toJson();

      expect(json['pageNumber'], 0);
      expect(json['strokes'], isA<List>());
      expect((json['strokes'] as List).length, 1);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'pageNumber': 2,
        'strokes': [
          {
            'points': [
              {'x': 1.0, 'y': 2.0},
            ],
            'color': Colors.blue.toARGB32(),
            'thickness': 5.0,
            'type': 'pen',
          },
        ],
      };
      final page = SidecarPageAnnotations.fromJson(json);

      expect(page.pageNumber, 2);
      expect(page.strokes.length, 1);
      expect(page.strokes[0].thickness, 5.0);
    });

    test('roundtrip preserves data', () {
      final stroke = DrawingStroke(
        points: [const Offset(5, 10), const Offset(15, 20)],
        color: const Color(0xFF00FF00),
        thickness: 2.0,
        type: AnnotationType.highlighter,
      );
      final original = SidecarPageAnnotations(pageNumber: 3, strokes: [stroke]);
      final restored = SidecarPageAnnotations.fromJson(original.toJson());

      expect(restored.pageNumber, original.pageNumber);
      expect(restored.strokes.length, original.strokes.length);
      expect(
        restored.strokes[0].color.toARGB32(),
        original.strokes[0].color.toARGB32(),
      );
    });
  });

  group('SidecarLayer', () {
    test('toJson serializes correctly', () {
      final layer = SidecarLayer(
        name: 'Layer 1',
        isVisible: true,
        orderIndex: 0,
        annotations: [],
      );
      final json = layer.toJson();

      expect(json['name'], 'Layer 1');
      expect(json['isVisible'], true);
      expect(json['orderIndex'], 0);
      expect(json['annotations'], isEmpty);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'name': 'Highlights',
        'isVisible': false,
        'orderIndex': 2,
        'annotations': <Map<String, dynamic>>[],
      };
      final layer = SidecarLayer.fromJson(json);

      expect(layer.name, 'Highlights');
      expect(layer.isVisible, false);
      expect(layer.orderIndex, 2);
      expect(layer.annotations, isEmpty);
    });

    test('roundtrip with annotations preserves data', () {
      final stroke = DrawingStroke(
        points: [const Offset(0, 0)],
        color: Colors.black,
        thickness: 1.0,
        type: AnnotationType.pen,
      );
      final original = SidecarLayer(
        name: 'Notes',
        isVisible: true,
        orderIndex: 1,
        annotations: [
          SidecarPageAnnotations(pageNumber: 0, strokes: [stroke]),
          SidecarPageAnnotations(pageNumber: 1, strokes: []),
        ],
      );
      final restored = SidecarLayer.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.isVisible, original.isVisible);
      expect(restored.orderIndex, original.orderIndex);
      expect(restored.annotations.length, 2);
      expect(restored.annotations[0].strokes.length, 1);
      expect(restored.annotations[1].strokes.length, 0);
    });
  });

  group('AnnotationSidecar', () {
    test('toJson serializes correctly', () {
      final now = DateTime.utc(2025, 6, 15, 10, 30, 0);
      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: now,
        layers: [],
      );
      final json = sidecar.toJson();

      expect(json['version'], 1);
      expect(json['modifiedAt'], '2025-06-15T10:30:00.000Z');
      expect(json['layers'], isEmpty);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'version': 1,
        'modifiedAt': '2025-06-15T10:30:00.000Z',
        'layers': <Map<String, dynamic>>[],
      };
      final sidecar = AnnotationSidecar.fromJson(json);

      expect(sidecar.version, 1);
      expect(sidecar.modifiedAt, DateTime.utc(2025, 6, 15, 10, 30, 0));
      expect(sidecar.layers, isEmpty);
    });

    test('modifiedAt is serialized as UTC ISO 8601', () {
      // Even if a local DateTime is provided, it should serialize as UTC
      final localTime = DateTime(2025, 6, 15, 12, 0, 0);
      final sidecar = AnnotationSidecar(
        version: 1,
        modifiedAt: localTime,
        layers: [],
      );
      final json = sidecar.toJson();
      final dateStr = json['modifiedAt'] as String;

      expect(dateStr, endsWith('Z'));
    });

    test('full roundtrip with all nested data', () {
      final stroke1 = DrawingStroke(
        points: [const Offset(10, 20), const Offset(30, 40)],
        color: Colors.red,
        thickness: 3.0,
        type: AnnotationType.pen,
      );
      final stroke2 = DrawingStroke(
        points: [const Offset(50, 60)],
        color: const Color(0x80FFFF00),
        thickness: 10.0,
        type: AnnotationType.highlighter,
      );

      final original = AnnotationSidecar(
        version: 1,
        modifiedAt: DateTime.utc(2025, 1, 1),
        layers: [
          SidecarLayer(
            name: 'Default',
            isVisible: true,
            orderIndex: 0,
            annotations: [
              SidecarPageAnnotations(pageNumber: 0, strokes: [stroke1]),
              SidecarPageAnnotations(pageNumber: 1, strokes: [stroke2]),
            ],
          ),
          SidecarLayer(
            name: 'Hidden',
            isVisible: false,
            orderIndex: 1,
            annotations: [],
          ),
        ],
      );

      final restored = AnnotationSidecar.fromJson(original.toJson());

      expect(restored.version, 1);
      expect(restored.modifiedAt, DateTime.utc(2025, 1, 1));
      expect(restored.layers.length, 2);
      expect(restored.layers[0].name, 'Default');
      expect(restored.layers[0].annotations.length, 2);
      expect(restored.layers[0].annotations[0].strokes.length, 1);
      expect(
        restored.layers[0].annotations[0].strokes[0].color.toARGB32(),
        Colors.red.toARGB32(),
      );
      expect(restored.layers[1].name, 'Hidden');
      expect(restored.layers[1].isVisible, false);
      expect(restored.layers[1].annotations, isEmpty);
    });
  });
}
