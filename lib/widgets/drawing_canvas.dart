import 'package:flutter/material.dart';
import '../services/annotation_service.dart';

/// Canvas widget for drawing annotations
class DrawingCanvas extends StatefulWidget {
  final int layerId;
  final int pageNumber;
  final AnnotationType toolType;
  final Color color;
  final double thickness;

  /// Annotations grouped by layer ID - erasers only affect their own layer
  final Map<int, List<DrawingStroke>> layerAnnotations;
  final VoidCallback? onStrokeCompleted;
  final bool isEnabled;

  const DrawingCanvas({
    super.key,
    required this.layerId,
    required this.pageNumber,
    required this.toolType,
    required this.color,
    required this.thickness,
    required this.layerAnnotations,
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
  void initState() {
    super.initState();
    debugPrint('[DrawingCanvas] initState layer=${widget.layerId} page=${widget.pageNumber} enabled=${widget.isEnabled}');
  }

  @override
  void dispose() {
    debugPrint('[DrawingCanvas] dispose layer=${widget.layerId} page=${widget.pageNumber} sessionStrokes=${_currentSessionStrokes.length}');
    super.dispose();
  }

  @override
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear session strokes when layer or page changes to avoid stale annotations
    if (oldWidget.layerId != widget.layerId ||
        oldWidget.pageNumber != widget.pageNumber) {
      debugPrint('[DrawingCanvas] didUpdateWidget CLEARING session strokes (layer ${oldWidget.layerId}->${widget.layerId}, page ${oldWidget.pageNumber}->${widget.pageNumber})');
      _currentSessionStrokes.clear();
      _currentStroke = null;
    }
    if (oldWidget.isEnabled != widget.isEnabled) {
      debugPrint('[DrawingCanvas] didUpdateWidget enabled ${oldWidget.isEnabled}->${widget.isEnabled}, sessionStrokes=${_currentSessionStrokes.length}');
    }
    if (oldWidget.layerAnnotations != widget.layerAnnotations) {
      final oldCounts = oldWidget.layerAnnotations.map((k, v) => MapEntry(k, v.length));
      final newCounts = widget.layerAnnotations.map((k, v) => MapEntry(k, v.length));
      debugPrint('[DrawingCanvas] didUpdateWidget layerAnnotations changed: $oldCounts -> $newCounts');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Listener instead of GestureDetector for raw pointer events.
    // GestureDetector's PanGestureRecognizer requires ~18px of movement
    // ("slop") before recognizing the gesture, losing the start of each stroke.
    // Listener bypasses the gesture arena entirely for zero-delay response.
    return Listener(
      onPointerDown: widget.isEnabled ? _onPointerDown : null,
      onPointerMove: widget.isEnabled ? _onPointerMove : null,
      onPointerUp: widget.isEnabled ? _onPointerUp : null,
      child: CustomPaint(
        painter: DrawingPainter(
          layerAnnotations: widget.layerAnnotations,
          activeLayerId: widget.layerId,
          currentSessionStrokes: _currentSessionStrokes,
          currentStroke: _currentStroke,
        ),
        child: Container(),
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _currentStroke = DrawingStroke(
        points: [event.localPosition],
        color: widget.color,
        thickness: widget.thickness,
        type: widget.toolType,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_currentStroke == null) return;

    setState(() {
      _currentStroke = DrawingStroke(
        points: [..._currentStroke!.points, event.localPosition],
        color: _currentStroke!.color,
        thickness: _currentStroke!.thickness,
        type: _currentStroke!.type,
      );
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_currentStroke == null) return;

    final stroke = _currentStroke!;
    setState(() {
      _currentSessionStrokes.add(stroke);
      _currentStroke = null;
    });

    debugPrint('[DrawingCanvas] onPointerUp: stroke completed (${stroke.type}, ${stroke.points.length} pts), sessionStrokes now=${_currentSessionStrokes.length}');

    // Save the stroke to database and THEN notify completion
    _saveAndNotify(stroke);
  }

  Future<void> _saveAndNotify(DrawingStroke stroke) async {
    final annotationService = AnnotationService.instance;
    final stopwatch = Stopwatch()..start();

    try {
      final id = await annotationService.saveAnnotation(
        layerId: widget.layerId,
        pageNumber: widget.pageNumber,
        stroke: stroke,
      );
      stopwatch.stop();
      debugPrint('[DrawingCanvas] save SUCCESS id=$id in ${stopwatch.elapsedMilliseconds}ms (layer=${widget.layerId}, page=${widget.pageNumber}, type=${stroke.type})');
    } catch (e) {
      stopwatch.stop();
      debugPrint('[DrawingCanvas] save FAILED in ${stopwatch.elapsedMilliseconds}ms: $e');
    }

    // Notify completion AFTER save
    debugPrint('[DrawingCanvas] notifying onStrokeCompleted');
    widget.onStrokeCompleted?.call();
  }
}

/// Custom painter for drawing strokes
class DrawingPainter extends CustomPainter {
  /// Annotations grouped by layer ID
  final Map<int, List<DrawingStroke>> layerAnnotations;

  /// The currently active layer (for session strokes)
  final int activeLayerId;
  final List<DrawingStroke> currentSessionStrokes;
  final DrawingStroke? currentStroke;

  DrawingPainter({
    required this.layerAnnotations,
    required this.activeLayerId,
    required this.currentSessionStrokes,
    this.currentStroke,
  });

  static int _lastLoggedSessionCount = -1;
  static int _lastLoggedLayerHash = -1;

  @override
  void paint(Canvas canvas, Size size) {
    // Log only when state changes (not every frame)
    final layerHash = Object.hashAll(layerAnnotations.entries.map((e) => '${e.key}:${e.value.length}'));
    if (currentSessionStrokes.length != _lastLoggedSessionCount || layerHash != _lastLoggedLayerHash) {
      final layerCounts = layerAnnotations.map((k, v) => MapEntry(k, v.length));
      debugPrint('[DrawingPainter] paint state changed: layers=$layerCounts activeLayer=$activeLayerId sessionStrokes=${currentSessionStrokes.length} currentStroke=${currentStroke != null}');
      _lastLoggedSessionCount = currentSessionStrokes.length;
      _lastLoggedLayerHash = layerHash;
    }

    // Render each layer separately so erasers only affect their own layer
    for (final entry in layerAnnotations.entries) {
      final layerId = entry.key;
      final strokes = entry.value;

      // Use saveLayer for each layer so BlendMode.clear only affects this layer
      canvas.saveLayer(Offset.zero & size, Paint());

      // Draw this layer's strokes
      for (final stroke in strokes) {
        _drawStroke(canvas, stroke);
      }

      // If this is the active layer, also draw current session strokes
      if (layerId == activeLayerId) {
        for (final stroke in currentSessionStrokes) {
          _drawStroke(canvas, stroke);
        }

        // Draw current stroke being drawn
        if (currentStroke != null) {
          _drawStroke(canvas, currentStroke!);
        }
      }

      canvas.restore();
    }

    // If active layer has no existing strokes but has session strokes, draw them
    if (!layerAnnotations.containsKey(activeLayerId) &&
        (currentSessionStrokes.isNotEmpty || currentStroke != null)) {
      canvas.saveLayer(Offset.zero & size, Paint());

      for (final stroke in currentSessionStrokes) {
        _drawStroke(canvas, stroke);
      }

      if (currentStroke != null) {
        _drawStroke(canvas, currentStroke!);
      }

      canvas.restore();
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
    return oldDelegate.layerAnnotations != layerAnnotations ||
        oldDelegate.activeLayerId != activeLayerId ||
        oldDelegate.currentSessionStrokes != currentSessionStrokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}
