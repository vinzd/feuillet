import 'package:flutter/material.dart';

/// Immutable display settings for PDF viewing.
///
/// Contains zoom, brightness, and contrast values along with
/// utility methods for creating color filters.
@immutable
class DisplaySettings {
  const DisplaySettings({
    this.zoomLevel = 1.0,
    this.brightness = 0.0,
    this.contrast = 1.0,
  });

  /// Default display settings
  static const defaults = DisplaySettings();

  /// Zoom level (0.5 to 3.0, default 1.0)
  final double zoomLevel;

  /// Brightness adjustment (-0.5 to 0.5, default 0.0)
  final double brightness;

  /// Contrast adjustment (0.5 to 2.0, default 1.0)
  final double contrast;

  /// Minimum zoom level
  static const double minZoom = 0.5;

  /// Maximum zoom level
  static const double maxZoom = 3.0;

  /// Minimum brightness
  static const double minBrightness = -0.5;

  /// Maximum brightness
  static const double maxBrightness = 0.5;

  /// Minimum contrast
  static const double minContrast = 0.5;

  /// Maximum contrast
  static const double maxContrast = 2.0;

  /// Creates a color matrix for brightness and contrast adjustment.
  ///
  /// This matrix can be used with [ColorFilter.matrix] to apply
  /// brightness and contrast adjustments to PDF pages.
  List<double> createColorMatrix() {
    final double b = brightness * 255;
    final double c = contrast;

    return [
      c, 0, 0, 0, b, // Red
      0, c, 0, 0, b, // Green
      0, 0, c, 0, b, // Blue
      0, 0, 0, 1, 0, // Alpha
    ];
  }

  /// Creates a [ColorFilter] from the current brightness and contrast settings.
  ColorFilter get colorFilter => ColorFilter.matrix(createColorMatrix());

  /// Whether the settings are at their default values
  bool get isDefault =>
      zoomLevel == 1.0 && brightness == 0.0 && contrast == 1.0;

  /// Creates a copy with the given fields replaced
  DisplaySettings copyWith({
    double? zoomLevel,
    double? brightness,
    double? contrast,
  }) {
    return DisplaySettings(
      zoomLevel: zoomLevel ?? this.zoomLevel,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DisplaySettings &&
        other.zoomLevel == zoomLevel &&
        other.brightness == brightness &&
        other.contrast == contrast;
  }

  @override
  int get hashCode => Object.hash(zoomLevel, brightness, contrast);

  @override
  String toString() =>
      'DisplaySettings(zoom: $zoomLevel, brightness: $brightness, contrast: $contrast)';
}
