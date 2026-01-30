import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

import '../models/database.dart';
import 'annotation_service.dart';

/// Service for exporting PDFs with annotations burned in
class PdfExportService {
  static PdfExportService? _instance;
  static PdfExportService get instance => _instance ??= PdfExportService._();
  PdfExportService._();

  final _annotationService = AnnotationService();

  /// Scale factor used when rendering annotations (from PdfPageCacheService)
  static const double annotationScale = 2.0;

  /// Scale factor for export quality (higher = better quality but larger file)
  /// 3.0 gives approximately 216 DPI which is good for print quality
  static const double exportScale = 3.0;

  /// Export a PDF with selected annotation layers burned in
  ///
  /// Returns the generated PDF as bytes
  Future<Uint8List> exportPdfWithAnnotations({
    required Document document,
    required pdfx.PdfDocument pdfDoc,
    required List<int> selectedLayerIds,
    void Function(int current, int total)? onProgress,
  }) async {
    final pdf = pw.Document();
    final totalPages = pdfDoc.pagesCount;

    for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
      onProgress?.call(pageNum, totalPages);

      // Get the original PDF page
      final page = await pdfDoc.getPage(pageNum);

      try {
        // Render page at higher resolution for better quality
        // Using exportScale (3x) gives ~216 DPI for standard 72 DPI PDFs
        final renderWidth = page.width * exportScale;
        final renderHeight = page.height * exportScale;

        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
        );

        if (pageImage == null) {
          debugPrint('Failed to render page $pageNum');
          continue;
        }

        // Get annotations for this page from selected layers
        final annotations = await _getPageAnnotations(
          document.id,
          pageNum - 1, // 0-indexed for annotations
          selectedLayerIds,
        );

        // Create PDF page with image and annotations
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (context) {
              return pw.Stack(
                children: [
                  // Background PDF page image
                  pw.Image(
                    pw.MemoryImage(pageImage.bytes),
                    fit: pw.BoxFit.fill,
                    width: page.width,
                    height: page.height,
                  ),
                  // Annotations overlay
                  if (annotations.isNotEmpty)
                    pw.CustomPaint(
                      size: PdfPoint(page.width, page.height),
                      painter: (canvas, size) {
                        _drawAnnotations(
                          canvas,
                          annotations,
                          size.y, // PDF Y coordinates are flipped
                        );
                      },
                    ),
                ],
              );
            },
          ),
        );
      } finally {
        await page.close();
      }
    }

    return pdf.save();
  }

  /// Get annotations for a specific page from selected layers
  Future<List<DrawingStroke>> _getPageAnnotations(
    int documentId,
    int pageNumber,
    List<int> selectedLayerIds,
  ) async {
    final allAnnotations = <DrawingStroke>[];

    for (final layerId in selectedLayerIds) {
      final layerAnnotations = await _annotationService.getAnnotations(
        layerId,
        pageNumber,
      );
      allAnnotations.addAll(layerAnnotations);
    }

    return allAnnotations;
  }

  /// Draw annotations onto PDF canvas
  void _drawAnnotations(
    PdfGraphics canvas,
    List<DrawingStroke> annotations,
    double pageHeight,
  ) {
    for (final stroke in annotations) {
      _drawStrokeToPdf(canvas, stroke, pageHeight);
    }
  }

  /// Draw a single stroke to PDF canvas
  /// Adapted from DrawingPainter._drawStroke() in drawing_canvas.dart
  void _drawStrokeToPdf(
    PdfGraphics canvas,
    DrawingStroke stroke,
    double pageHeight,
  ) {
    if (stroke.points.isEmpty) return;

    // Skip non-drawable stroke types
    if (stroke.type == AnnotationType.eraser ||
        stroke.type == AnnotationType.text) {
      return;
    }

    // Convert annotation coordinates to PDF coordinates.
    // Annotations are stored at 2x scale, so divide by annotationScale.
    // PDF Y coordinates are flipped (origin at bottom-left).
    final scaledPoints = stroke.points.map((p) {
      final x = p.dx / annotationScale;
      final y = pageHeight - (p.dy / annotationScale);
      return PdfPoint(x, y);
    }).toList();

    var thickness = stroke.thickness / annotationScale;
    final color = PdfColor.fromInt(stroke.color.toARGB32());

    // Set up stroke properties based on type
    switch (stroke.type) {
      case AnnotationType.pen:
        canvas.setStrokeColor(color);
      case AnnotationType.highlighter:
        canvas.setStrokeColor(color);
        canvas.setGraphicState(PdfGraphicState(strokeOpacity: 0.4));
        thickness *= 2;
      case AnnotationType.eraser:
      case AnnotationType.text:
        // Already handled above
        return;
    }

    canvas.setLineWidth(thickness);
    canvas.setLineCap(PdfLineCap.round);
    canvas.setLineJoin(PdfLineJoin.round);

    if (scaledPoints.length == 1) {
      // Single point - draw a filled circle
      final point = scaledPoints.first;
      canvas.drawEllipse(point.x, point.y, thickness / 2, thickness / 2);
      canvas.setFillColor(PdfColor.fromInt(stroke.color.toARGB32()));
      if (stroke.type == AnnotationType.highlighter) {
        canvas.setGraphicState(PdfGraphicState(fillOpacity: 0.4));
      }
      canvas.fillPath();
    } else {
      // Multiple points - draw path
      canvas.moveTo(scaledPoints.first.x, scaledPoints.first.y);
      for (int i = 1; i < scaledPoints.length; i++) {
        canvas.lineTo(scaledPoints[i].x, scaledPoints[i].y);
      }
      canvas.strokePath();
    }

    // Reset graphic state
    canvas.setGraphicState(
      PdfGraphicState(strokeOpacity: 1.0, fillOpacity: 1.0),
    );
  }

  /// Share the exported PDF using platform share sheet.
  /// Note: On web, use the platform-specific downloadPdf function instead.
  Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'sharePdf is not supported on web. Use platform.downloadPdf instead.',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = path.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'application/pdf')],
        subject: fileName,
      ),
    );
  }
}
