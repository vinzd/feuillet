import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/view_mode.dart';
import '../services/annotation_service.dart';
import 'cached_pdf_page.dart';
import 'drawing_canvas.dart';

/// A widget that displays two PDF pages side by side.
///
/// This widget is used in booklet and continuous double page view modes.
/// It allows selecting which page is active for annotation editing.
class TwoPagePdfView extends StatelessWidget {
  const TwoPagePdfView({
    required this.document,
    required this.leftPageNumber,
    this.rightPageNumber,
    required this.activePageSide,
    required this.onPageSideSelected,
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

  /// Which page is currently active for editing
  final PageSide activePageSide;

  /// Callback when a page side is tapped to select it
  final void Function(PageSide side) onPageSideSelected;

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
        // Left page
        Expanded(
          child: _PageContainer(
            document: document,
            pageNumber: leftPageNumber,
            isActive: activePageSide == PageSide.left,
            onTap: () => onPageSideSelected(PageSide.left),
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
        // Right page (or empty space if no right page)
        Expanded(
          child: rightPageNumber != null
              ? _PageContainer(
                  document: document,
                  pageNumber: rightPageNumber!,
                  isActive: activePageSide == PageSide.right,
                  onTap: () => onPageSideSelected(PageSide.right),
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
                  decoration: backgroundDecoration,
                  color: backgroundDecoration == null ? Colors.black : null,
                ),
        ),
      ],
    );
  }
}

/// Internal widget for a single page container with selection indicator
class _PageContainer extends StatelessWidget {
  const _PageContainer({
    required this.document,
    required this.pageNumber,
    required this.isActive,
    required this.onTap,
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
  final bool isActive;
  final VoidCallback onTap;
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
    final theme = Theme.of(context);
    final isEditable = isAnnotationMode && isActive && selectedLayerId != null;

    // Build annotation overlay widget
    Widget? annotationOverlay;
    if (selectedLayerId != null) {
      annotationOverlay = DrawingCanvas(
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        // Use CachedPdfPage with annotationOverlay - the FittedBox inside
        // ensures PDF and annotations scale together consistently
        child: CachedPdfPage(
          document: document,
          pageNumber: pageNumber,
          backgroundDecoration: backgroundDecoration,
          annotationOverlay: annotationOverlay,
        ),
      ),
    );
  }
}
