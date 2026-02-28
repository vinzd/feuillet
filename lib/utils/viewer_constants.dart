import 'package:flutter/material.dart';

/// Shared constants for PDF and setlist viewer overlays.
class ViewerConstants {
  ViewerConstants._();

  // Overlay background
  static const double overlayOpacity = 0.85;
  static final Color overlayBackground =
      Colors.black.withValues(alpha: overlayOpacity);

  // Animation durations
  static const Duration overlayAnimationDuration =
      Duration(milliseconds: 300);
  static const Duration pageAnimationDuration = Duration(milliseconds: 300);
  static const Curve pageAnimationCurve = Curves.easeInOut;

  // Overlay hide offsets (negative = off-screen)
  static const double overlayHideOffsetTop = -100;
  static const double overlayHideOffsetBottom = -100;
  static const double overlayHideOffsetBottomTall = -200;

  // Modal bottom sheet background
  static final Color modalBackground = Colors.grey[900]!;
}
