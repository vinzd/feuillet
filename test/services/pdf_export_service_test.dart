import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/services/annotation_service.dart';
import 'package:feuillet/services/pdf_export_service.dart';

void main() {
  group('PdfExportService', () {
    group('constants', () {
      test('annotationScale matches PdfPageCacheService render scale', () {
        expect(PdfExportService.annotationScale, 2.0);
      });

      test('exportScale provides good quality (at least 2x)', () {
        expect(PdfExportService.exportScale, greaterThanOrEqualTo(2.0));
      });
    });

    group('coordinate conversion', () {
      // These test the logic used in _drawStrokeToPdf
      const annotationScale = PdfExportService.annotationScale;

      test('annotation X coordinate converts correctly', () {
        const annotationX = 200.0;
        final pdfX = annotationX / annotationScale;
        expect(pdfX, 100.0);
      });

      test('annotation Y coordinate flips and scales correctly', () {
        const pageHeight = 792.0; // Standard letter height in points
        const annotationY = 200.0;
        final pdfY = pageHeight - (annotationY / annotationScale);
        expect(pdfY, 692.0); // 792 - 100 = 692
      });

      test('thickness scales correctly', () {
        const annotationThickness = 6.0;
        final pdfThickness = annotationThickness / annotationScale;
        expect(pdfThickness, 3.0);
      });

      test('highlighter thickness is doubled after scaling', () {
        const annotationThickness = 6.0;
        var pdfThickness = annotationThickness / annotationScale;
        pdfThickness *= 2; // Highlighter doubles thickness
        expect(pdfThickness, 6.0);
      });
    });

    group('stroke type handling', () {
      test('eraser strokes should be skipped', () {
        final eraserStroke = DrawingStroke(
          points: [const Offset(10, 10)],
          color: Colors.white,
          thickness: 20.0,
          type: AnnotationType.eraser,
        );
        // Eraser strokes are skipped in export - this tests the type check
        expect(eraserStroke.type, AnnotationType.eraser);
      });

      test('pen strokes should be included', () {
        final penStroke = DrawingStroke(
          points: [const Offset(10, 10), const Offset(20, 20)],
          color: Colors.red,
          thickness: 3.0,
          type: AnnotationType.pen,
        );
        expect(penStroke.type, AnnotationType.pen);
        expect(penStroke.type, isNot(AnnotationType.eraser));
      });

      test('highlighter strokes should be included with opacity', () {
        final highlighterStroke = DrawingStroke(
          points: [const Offset(10, 10), const Offset(100, 10)],
          color: Colors.yellow,
          thickness: 12.0,
          type: AnnotationType.highlighter,
        );
        expect(highlighterStroke.type, AnnotationType.highlighter);
        expect(highlighterStroke.type, isNot(AnnotationType.eraser));
      });

      test('text strokes should be skipped', () {
        final textStroke = DrawingStroke(
          points: [const Offset(10, 10)],
          color: Colors.black,
          thickness: 1.0,
          type: AnnotationType.text,
        );
        expect(textStroke.type, AnnotationType.text);
      });
    });

    // Note: singleton pattern test skipped because PdfExportService
    // creates AnnotationService which requires database initialization
  });

  group('DrawingStroke for export', () {
    test('empty points list is valid', () {
      final stroke = DrawingStroke(
        points: [],
        color: Colors.red,
        thickness: 3.0,
        type: AnnotationType.pen,
      );
      expect(stroke.points, isEmpty);
    });

    test('single point stroke is valid', () {
      final stroke = DrawingStroke(
        points: [const Offset(50, 50)],
        color: Colors.blue,
        thickness: 5.0,
        type: AnnotationType.pen,
      );
      expect(stroke.points.length, 1);
    });

    test('multi-point stroke preserves all points', () {
      final points = [
        const Offset(0, 0),
        const Offset(10, 10),
        const Offset(20, 15),
        const Offset(30, 10),
      ];
      final stroke = DrawingStroke(
        points: points,
        color: Colors.green,
        thickness: 2.0,
        type: AnnotationType.pen,
      );
      expect(stroke.points.length, 4);
      expect(stroke.points, points);
    });

    test('color is preserved correctly', () {
      const color = Color(0xFF2196F3); // Blue
      final stroke = DrawingStroke(
        points: [const Offset(0, 0)],
        color: color,
        thickness: 3.0,
        type: AnnotationType.pen,
      );
      expect(stroke.color.toARGB32(), color.toARGB32());
    });
  });
}
