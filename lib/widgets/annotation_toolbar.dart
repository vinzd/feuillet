import 'package:flutter/material.dart';
import '../services/annotation_service.dart';

/// Toolbar for annotation drawing tools
class AnnotationToolbar extends StatelessWidget {
  final AnnotationType currentTool;
  final Color annotationColor;
  final double annotationThickness;
  final ValueChanged<AnnotationType> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onThicknessChanged;

  const AnnotationToolbar({
    super.key,
    required this.currentTool,
    required this.annotationColor,
    required this.annotationThickness,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onThicknessChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tool selection
          _ToolButton(
            tool: AnnotationType.pen,
            icon: Icons.edit,
            tooltip: 'Pen',
            isSelected: currentTool == AnnotationType.pen,
            onPressed: () => onToolChanged(AnnotationType.pen),
          ),
          _ToolButton(
            tool: AnnotationType.highlighter,
            icon: Icons.highlight,
            tooltip: 'Highlighter',
            isSelected: currentTool == AnnotationType.highlighter,
            onPressed: () => onToolChanged(AnnotationType.highlighter),
          ),
          _ToolButton(
            tool: AnnotationType.eraser,
            icon: Icons.auto_fix_high,
            tooltip: 'Eraser',
            isSelected: currentTool == AnnotationType.eraser,
            onPressed: () => onToolChanged(AnnotationType.eraser),
          ),

          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 16),

          // Color picker
          _ColorButton(
            color: Colors.red,
            isSelected: annotationColor == Colors.red,
            onTap: () => onColorChanged(Colors.red),
          ),
          _ColorButton(
            color: Colors.blue,
            isSelected: annotationColor == Colors.blue,
            onTap: () => onColorChanged(Colors.blue),
          ),
          _ColorButton(
            color: Colors.green,
            isSelected: annotationColor == Colors.green,
            onTap: () => onColorChanged(Colors.green),
          ),
          _ColorButton(
            color: Colors.yellow,
            isSelected: annotationColor == Colors.yellow,
            onTap: () => onColorChanged(Colors.yellow),
          ),
          _ColorButton(
            color: Colors.black,
            isSelected: annotationColor == Colors.black,
            onTap: () => onColorChanged(Colors.black),
          ),

          const SizedBox(width: 16),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 16),

          // Thickness selector
          IconButton(
            icon: Icon(
              Icons.line_weight,
              color: Colors.white,
              size: 20 + annotationThickness,
            ),
            onPressed: () {
              final newThickness =
                  annotationThickness >= 10 ? 2.0 : annotationThickness + 2;
              onThicknessChanged(newThickness);
            },
          ),
        ],
      ),
    );
  }
}

/// Tool button widget
class _ToolButton extends StatelessWidget {
  final AnnotationType tool;
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: isSelected ? Colors.blue : Colors.white,
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

/// Color button widget
class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
