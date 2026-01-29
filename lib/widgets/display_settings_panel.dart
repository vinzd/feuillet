import 'package:flutter/material.dart';

import '../utils/display_settings.dart';

/// Panel for brightness and contrast adjustments
class DisplaySettingsPanel extends StatefulWidget {
  final double brightness;
  final double contrast;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final VoidCallback onReset;

  const DisplaySettingsPanel({
    super.key,
    required this.brightness,
    required this.contrast,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onReset,
  });

  @override
  State<DisplaySettingsPanel> createState() => _DisplaySettingsPanelState();
}

class _DisplaySettingsPanelState extends State<DisplaySettingsPanel> {
  late double _brightness;
  late double _contrast;

  @override
  void initState() {
    super.initState();
    _brightness = widget.brightness;
    _contrast = widget.contrast;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Brightness
          const Text('Brightness', style: TextStyle(color: Colors.white70)),
          Slider(
            value: _brightness,
            min: DisplaySettings.minBrightness,
            max: DisplaySettings.maxBrightness,
            onChanged: (value) {
              setState(() => _brightness = value);
              widget.onBrightnessChanged(value);
            },
          ),

          const SizedBox(height: 16),

          // Contrast
          const Text('Contrast', style: TextStyle(color: Colors.white70)),
          Slider(
            value: _contrast,
            min: DisplaySettings.minContrast,
            max: DisplaySettings.maxContrast,
            onChanged: (value) {
              setState(() => _contrast = value);
              widget.onContrastChanged(value);
            },
          ),

          const SizedBox(height: 24),

          // Reset button
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _brightness = 0.0;
                  _contrast = 1.0;
                });
                widget.onReset();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset to defaults'),
            ),
          ),
        ],
      ),
    );
  }
}
