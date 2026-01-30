import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/widgets/drawing_canvas.dart';

void main() {
  group('DrawingCanvas Widget', () {
    Widget buildDrawingCanvas({
      int layerId = 1,
      int pageNumber = 0,
      Map<int, List<DrawingStroke>>? layerAnnotations,
      AnnotationType toolType = AnnotationType.pen,
      Color color = Colors.red,
      double thickness = 3.0,
      bool isEnabled = true,
      Key? key,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DrawingCanvas(
            key: key,
            layerId: layerId,
            pageNumber: pageNumber,
            layerAnnotations: layerAnnotations ?? {},
            toolType: toolType,
            color: color,
            thickness: thickness,
            onStrokeCompleted: () {},
            isEnabled: isEnabled,
          ),
        ),
      );
    }

    testWidgets('renders without error', (WidgetTester tester) async {
      await tester.pumpWidget(buildDrawingCanvas());
      expect(find.byType(DrawingCanvas), findsOneWidget);
    });

    testWidgets('accepts different tools', (WidgetTester tester) async {
      for (final tool in AnnotationType.values) {
        await tester.pumpWidget(buildDrawingCanvas(toolType: tool));
        expect(find.byType(DrawingCanvas), findsOneWidget);
      }
    });

    testWidgets('accepts different colors', (WidgetTester tester) async {
      final colors = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.black,
      ];

      for (final color in colors) {
        await tester.pumpWidget(buildDrawingCanvas(color: color));
        expect(find.byType(DrawingCanvas), findsOneWidget);
      }
    });

    testWidgets('accepts different thickness values', (
      WidgetTester tester,
    ) async {
      final thicknesses = [1.0, 2.0, 3.0, 5.0, 10.0];

      for (final thickness in thicknesses) {
        await tester.pumpWidget(buildDrawingCanvas(thickness: thickness));
        expect(find.byType(DrawingCanvas), findsOneWidget);
      }
    });

    testWidgets('isEnabled controls gesture detection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildDrawingCanvas(isEnabled: false));

      expect(find.byType(DrawingCanvas), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('rebuilds when layerId changes', (WidgetTester tester) async {
      await tester.pumpWidget(buildDrawingCanvas(layerId: 1));
      await tester.pumpWidget(buildDrawingCanvas(layerId: 2));
      expect(find.byType(DrawingCanvas), findsOneWidget);
    });

    testWidgets('rebuilds when pageNumber changes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildDrawingCanvas(pageNumber: 0));
      await tester.pumpWidget(buildDrawingCanvas(pageNumber: 1));
      expect(find.byType(DrawingCanvas), findsOneWidget);
    });

    testWidgets('uses ValueKey for proper widget recreation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildDrawingCanvas(key: const ValueKey('1-0'), layerId: 1),
      );
      expect(find.byType(DrawingCanvas), findsOneWidget);

      await tester.pumpWidget(
        buildDrawingCanvas(key: const ValueKey('2-0'), layerId: 2),
      );
      expect(find.byType(DrawingCanvas), findsOneWidget);
    });
  });
}
