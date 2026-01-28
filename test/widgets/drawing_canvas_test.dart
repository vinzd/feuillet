import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/services/annotation_service.dart';
import 'package:open_score/widgets/drawing_canvas.dart';

void main() {
  group('DrawingCanvas Widget', () {
    testWidgets('renders without error', (WidgetTester tester) async {
      final strokes = <DrawingStroke>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DrawingCanvas(
              layerId: 1,
              pageNumber: 0,
              existingStrokes: strokes,
              toolType: AnnotationType.pen,
              color: Colors.red,
              thickness: 3.0,
              onStrokeCompleted: () {},
            ),
          ),
        ),
      );

      expect(find.byType(DrawingCanvas), findsOneWidget);
    });

    testWidgets('accepts different tools', (WidgetTester tester) async {
      for (final tool in AnnotationType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DrawingCanvas(
                layerId: 1,
                pageNumber: 0,
                existingStrokes: [],
                toolType: tool,
                color: Colors.blue,
                thickness: 2.0,
                onStrokeCompleted: () {},
              ),
            ),
          ),
        );

        expect(find.byType(DrawingCanvas), findsOneWidget);
      }
    });

    testWidgets('accepts different colors', (WidgetTester tester) async {
      final colors = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.black
      ];

      for (final color in colors) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DrawingCanvas(
                layerId: 1,
                pageNumber: 0,
                existingStrokes: [],
                toolType: AnnotationType.pen,
                color: color,
                thickness: 2.0,
                onStrokeCompleted: () {},
              ),
            ),
          ),
        );

        expect(find.byType(DrawingCanvas), findsOneWidget);
      }
    });

    testWidgets('accepts different thickness values',
        (WidgetTester tester) async {
      final thicknesses = [1.0, 2.0, 3.0, 5.0, 10.0];

      for (final thickness in thicknesses) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DrawingCanvas(
                layerId: 1,
                pageNumber: 0,
                existingStrokes: [],
                toolType: AnnotationType.pen,
                color: Colors.red,
                thickness: thickness,
                onStrokeCompleted: () {},
              ),
            ),
          ),
        );

        expect(find.byType(DrawingCanvas), findsOneWidget);
      }
    });

    // Note: Testing actual drawing gestures would require more complex setup
    // with gesture simulation and verification of the onStrokeCompleted callback
  });
}
