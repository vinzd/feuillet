import 'package:flutter/material.dart';
import '../services/annotation_service.dart';

/// Canvas widget for drawing annotations
class DrawingCanvas extends StatefulWidget {
  final int layerId;
  final int pageNumber;
  final AnnotationType toolType;
  final Color color;
  final double thickness;
  final List<DrawingStroke> existingStrokes;
  final VoidCallback? onStrokeCompleted;
  final bool isEnabled;

  const DrawingCanvas({
    super.key,
    required this.layerId,
    required this.pageNumber,
    required this.toolType,
    required this.color,
    required this.thickness,
    required this.existingStrokes,
    this.onStrokeCompleted,
    this.isEnabled = true,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<DrawingStroke> _currentSessionStrokes = [];
  DrawingStroke? _currentStroke;

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear session strokes when layer or page changes to avoid stale annotations
    if (oldWidget.layerId != widget.layerId ||
        oldWidget.pageNumber != widget.pageNumber) {
      _currentSessionStrokes.clear();
      _currentStroke = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.isEnabled ? _onPanStart : null,
      onPanUpdate: widget.isEnabled ? _onPanUpdate : null,
      onPanEnd: widget.isEnabled ? _onPanEnd : null,
      child: CustomPaint(
        painter: DrawingPainter(
          existingStrokes: widget.existingStrokes,
          currentSessionStrokes: _currentSessionStrokes,
          currentStroke: _currentStroke,
        ),
        child: Container(),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [details.localPosition],
        color: widget.color,
        thickness: widget.thickness,
        type: widget.toolType,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;

    setState(() {
      _currentStroke = DrawingStroke(
        points: [..._currentStroke!.points, details.localPosition],
        color: _currentStroke!.color,
        thickness: _currentStroke!.thickness,
        type: _currentStroke!.type,
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke == null) return;

    setState(() {
      _currentSessionStrokes.add(_currentStroke!);
      _currentStroke = null;
    });

    // Save the stroke to database
    _saveCurrentStroke();

    // Notify completion
    widget.onStrokeCompleted?.call();
  }

  Future<void> _saveCurrentStroke() async {
    if (_currentSessionStrokes.isEmpty) return;

    final stroke = _currentSessionStrokes.last;
    final annotationService = AnnotationService();

    try {
      await annotationService.saveAnnotation(
        layerId: widget.layerId,
        pageNumber: widget.pageNumber,
        stroke: stroke,
      );
    } catch (e) {
      debugPrint('[DrawingCanvas] Error saving annotation: $e');
    }
  }
}

/// Custom painter for drawing strokes
class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> existingStrokes;
  final List<DrawingStroke> currentSessionStrokes;
  final DrawingStroke? currentStroke;

  DrawingPainter({
    required this.existingStrokes,
    required this.currentSessionStrokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw existing strokes
    for (final stroke in existingStrokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current session strokes
    for (final stroke in currentSessionStrokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.thickness
      ..style = PaintingStyle.stroke;

    switch (stroke.type) {
      case AnnotationType.pen:
        paint.color = stroke.color;
        break;
      case AnnotationType.highlighter:
        paint.color = stroke.color.withValues(alpha: 0.4);
        paint.strokeWidth = stroke.thickness * 2;
        break;
      case AnnotationType.eraser:
        paint.color = Colors.white;
        paint.blendMode = BlendMode.clear;
        break;
      case AnnotationType.text:
        // Text annotations handled separately
        return;
    }

    // Draw the stroke path
    if (stroke.points.length == 1) {
      // Single point - draw a dot
      canvas.drawCircle(stroke.points.first, stroke.thickness / 2, paint);
    } else {
      // Multiple points - draw path
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return oldDelegate.existingStrokes != existingStrokes ||
        oldDelegate.currentSessionStrokes != currentSessionStrokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
