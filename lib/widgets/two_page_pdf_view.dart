import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/annotation_service.dart';
import 'cached_pdf_page.dart';
import 'drawing_canvas.dart';

/// A widget that displays two PDF pages side by side.
///
/// This widget is used in booklet and continuous double page view modes.
/// Both pages can be annotated simultaneously when annotation mode is enabled.
class TwoPagePdfView extends StatelessWidget {
  const TwoPagePdfView({
    required this.document,
    required this.leftPageNumber,
    this.rightPageNumber,
    this.leftPageAnnotations = const [],
    this.rightPageAnnotations = const [],
    this.isAnnotationMode = false,
    this.selectedLayerId,
    this.currentTool = AnnotationType.pen,
    this.annotationColor = Colors.red,
    this.annotationThickness = 3.0,
    this.onStrokeCompleted,
    this.backgroundDecoration,
    super.key,
  });

  /// The PDF document to display pages from
  final PdfDocument document;

  /// The page number for the left side (1-indexed)
  final int leftPageNumber;

  /// The page number for the right side (1-indexed), null if only one page
  final int? rightPageNumber;

  /// Annotations for the left page
  final List<DrawingStroke> leftPageAnnotations;

  /// Annotations for the right page
  final List<DrawingStroke> rightPageAnnotations;

  /// Whether annotation mode is enabled
  final bool isAnnotationMode;

  /// The currently selected annotation layer ID
  final int? selectedLayerId;

  /// The current annotation tool type
  final AnnotationType currentTool;

  /// The current annotation color
  final Color annotationColor;

  /// The current annotation thickness
  final double annotationThickness;

  /// Callback when a stroke is completed
  final VoidCallback? onStrokeCompleted;

  /// Background decoration for page containers
  final BoxDecoration? backgroundDecoration;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PageContainer(
            document: document,
            pageNumber: leftPageNumber,
            annotations: leftPageAnnotations,
            isAnnotationMode: isAnnotationMode,
            selectedLayerId: selectedLayerId,
            currentTool: currentTool,
            annotationColor: annotationColor,
            annotationThickness: annotationThickness,
            onStrokeCompleted: onStrokeCompleted,
            backgroundDecoration: backgroundDecoration,
          ),
        ),
        Expanded(
          child: rightPageNumber != null
              ? _PageContainer(
                  document: document,
                  pageNumber: rightPageNumber!,
                  annotations: rightPageAnnotations,
                  isAnnotationMode: isAnnotationMode,
                  selectedLayerId: selectedLayerId,
                  currentTool: currentTool,
                  annotationColor: annotationColor,
                  annotationThickness: annotationThickness,
                  onStrokeCompleted: onStrokeCompleted,
                  backgroundDecoration: backgroundDecoration,
                )
              : Container(
                  decoration:
                      backgroundDecoration ??
                      const BoxDecoration(color: Colors.black),
                ),
        ),
      ],
    );
  }
}

/// Internal widget for a single page container
class _PageContainer extends StatelessWidget {
  const _PageContainer({
    required this.document,
    required this.pageNumber,
    required this.annotations,
    required this.isAnnotationMode,
    this.selectedLayerId,
    required this.currentTool,
    required this.annotationColor,
    required this.annotationThickness,
    this.onStrokeCompleted,
    this.backgroundDecoration,
  });

  final PdfDocument document;
  final int pageNumber;
  final List<DrawingStroke> annotations;
  final bool isAnnotationMode;
  final int? selectedLayerId;
  final AnnotationType currentTool;
  final Color annotationColor;
  final double annotationThickness;
  final VoidCallback? onStrokeCompleted;
  final BoxDecoration? backgroundDecoration;

  @override
  Widget build(BuildContext context) {
    final isEditable = isAnnotationMode && selectedLayerId != null;

    Widget? annotationOverlay;
    if (selectedLayerId != null) {
      annotationOverlay = DrawingCanvas(
        key: ValueKey('$selectedLayerId-$pageNumber'),
        layerId: selectedLayerId!,
        pageNumber: pageNumber - 1,
        toolType: currentTool,
        color: annotationColor,
        thickness: annotationThickness,
        existingStrokes: annotations,
        onStrokeCompleted: onStrokeCompleted,
        isEnabled: isEditable,
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      child: CachedPdfPage(
        document: document,
        pageNumber: pageNumber,
        backgroundDecoration: backgroundDecoration,
        annotationOverlay: annotationOverlay,
      ),
    );
  }
}
