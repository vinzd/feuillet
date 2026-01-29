import 'package:flutter/material.dart';

import '../utils/display_settings.dart';

/// A horizontal zoom slider with icons and percentage display.
///
/// Used in both single document and setlist performance views
/// for consistent zoom control.
class ZoomSlider extends StatelessWidget {
  const ZoomSlider({
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.onInteraction,
    this.width = 200,
    super.key,
  });

  /// Current zoom level
  final double value;

  /// Called when the zoom level changes
  final ValueChanged<double> onChanged;

  /// Called when the user stops dragging the slider
  final ValueChanged<double>? onChangeEnd;

  /// Called when the user finishes interacting with the slider (for auto-hide timer reset)
  final VoidCallback? onInteraction;

  /// Width of the slider
  final double width;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
        SizedBox(
          width: width,
          child: Slider(
            value: value,
            min: DisplaySettings.minZoom,
            max: DisplaySettings.maxZoom,
            onChanged: onChanged,
            onChangeEnd: (newValue) {
              onChangeEnd?.call(newValue);
              onInteraction?.call();
            },
          ),
        ),
        const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
