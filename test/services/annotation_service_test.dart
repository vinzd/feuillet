import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/annotation_service.dart';

void main() {
  group('DrawingStroke', () {
    test('toJson serializes correctly', () {
      final stroke = DrawingStroke(
        points: [const Offset(10, 20), const Offset(30, 40)],
        color: Colors.red,
        thickness: 5.0,
        type: AnnotationType.pen,
      );

      final json = stroke.toJson();

      expect(json['points'], isA<List>());
      expect(json['points'].length, 2);
      expect(json['points'][0]['x'], 10.0);
      expect(json['points'][0]['y'], 20.0);
      expect(json['color'], isA<int>());
      expect(json['thickness'], 5.0);
      expect(json['type'], contains('pen'));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'points': [
          {'x': 10.0, 'y': 20.0},
          {'x': 30.0, 'y': 40.0},
        ],
        'color': Colors.red.toARGB32(),
        'thickness': 5.0,
        'type': 'AnnotationType.pen',
      };

      final stroke = DrawingStroke.fromJson(json);

      expect(stroke.points.length, 2);
      expect(stroke.points[0].dx, 10.0);
      expect(stroke.points[0].dy, 20.0);
      expect(stroke.color, Color(json['color'] as int));
      expect(stroke.thickness, 5.0);
      expect(stroke.type, AnnotationType.pen);
    });

    test('roundtrip serialization preserves data', () {
      final originalColor = const Color(0xFF2196F3); // Blue color
      final original = DrawingStroke(
        points: [const Offset(1, 2), const Offset(3, 4), const Offset(5, 6)],
        color: originalColor,
        thickness: 2.5,
        type: AnnotationType.highlighter,
      );

      final json = original.toJson();
      final restored = DrawingStroke.fromJson(json);

      expect(restored.points.length, original.points.length);
      expect(restored.points[0], original.points[0]);
      expect(restored.color.toARGB32(), original.color.toARGB32());
      expect(restored.thickness, original.thickness);
      expect(restored.type, original.type);
    });
  });

  group('AnnotationType', () {
    test('all annotation types are defined', () {
      expect(AnnotationType.pen, isNotNull);
      expect(AnnotationType.highlighter, isNotNull);
      expect(AnnotationType.eraser, isNotNull);
      expect(AnnotationType.text, isNotNull);
    });
  });

  group('AnnotationService', () {
    late AnnotationService service;

    setUp(() {
      service = AnnotationService();
    });

    test('service can be instantiated', () {
      expect(service, isNotNull);
    });

    // Note: More comprehensive tests would require mocking the database
    // These would include tests for:
    // - createLayer
    // - getLayers
    // - deleteLayer
    // - renameLayer
    // - saveAnnotation
    // - getAnnotations
    // - deleteAnnotation
  });
}
