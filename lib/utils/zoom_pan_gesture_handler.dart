import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'display_settings.dart';

/// State managed by [ZoomPanGestureMixin].
///
/// This class tracks the zoom and pan state during gesture handling.
class ZoomPanState {
  ZoomPanState({required this.displaySettings, this.panOffset = Offset.zero});

  DisplaySettings displaySettings;
  Offset panOffset;

  /// Baseline zoom level at gesture start (null when not in gesture).
  double? baseZoom;

  /// Baseline pan offset at gesture start (null when not in gesture).
  Offset? basePanOffset;
}

/// Mixin for handling pinch-to-zoom and pan gestures.
///
/// To use this mixin:
/// 1. Add `with ZoomPanGestureMixin` to your State class
/// 2. Initialize [zoomPanState] in initState
/// 3. Wrap your content with the gesture handling widgets using [buildZoomPanGestureDetector]
/// 4. Apply the transforms using [buildZoomPanTransform]
///
/// Example:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ZoomPanGestureMixin {
///   @override
///   late final ZoomPanState zoomPanState;
///
///   @override
///   void initState() {
///     super.initState();
///     zoomPanState = ZoomPanState(displaySettings: DisplaySettings.defaults);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return buildZoomPanGestureDetector(
///       child: buildZoomPanTransform(
///         child: MyContent(),
///       ),
///     );
///   }
/// }
/// ```
mixin ZoomPanGestureMixin<T extends StatefulWidget> on State<T> {
  /// The zoom/pan state. Must be initialized in subclass.
  ZoomPanState get zoomPanState;

  /// Override to return true when zoom/pan should be disabled (e.g., annotation mode).
  bool get isZoomPanDisabled => false;

  /// Called when a tap is detected (gesture ended without zoom or pan).
  void onZoomPanTap() {}

  /// Called when zoom changes are complete and should be persisted.
  void onZoomChanged() {}

  /// Sensitivity multiplier for trackpad pinch gestures.
  static const double _trackpadZoomSensitivity = 3.0;

  /// Handle scale gesture start.
  void handleScaleStart(ScaleStartDetails details) {
    zoomPanState.baseZoom = zoomPanState.displaySettings.zoomLevel;
    zoomPanState.basePanOffset = zoomPanState.panOffset;
  }

  /// Handle scale gesture update.
  void handleScaleUpdate(ScaleUpdateDetails details) {
    final state = zoomPanState;
    if (state.baseZoom == null || state.basePanOffset == null) return;
    if (isZoomPanDisabled) return;

    setState(() {
      // Handle pinch zoom (scale != 1.0)
      if (details.scale != 1.0) {
        final newZoom = (state.baseZoom! * details.scale).clamp(
          DisplaySettings.minZoom,
          DisplaySettings.maxZoom,
        );
        state.displaySettings = state.displaySettings.copyWith(
          zoomLevel: newZoom,
        );
      }

      // Handle pan (drag) - only when zoomed in
      if (state.displaySettings.zoomLevel > 1.0) {
        state.panOffset = state.basePanOffset! + details.focalPointDelta;
      }
    });
  }

  /// Handle scale gesture end.
  void handleScaleEnd(ScaleEndDetails details) {
    final state = zoomPanState;
    final didZoom = state.baseZoom != state.displaySettings.zoomLevel;
    final didPan = state.basePanOffset != state.panOffset;

    // Detect tap: gesture ended without zoom or pan
    if (!didZoom && !didPan) {
      onZoomPanTap();
    } else if (didZoom) {
      onZoomChanged();
    }

    // Reset pan when zoom returns to 1.0 or below
    if (state.displaySettings.zoomLevel <= 1.0) {
      state.panOffset = Offset.zero;
    }

    state.baseZoom = null;
    state.basePanOffset = null;
  }

  /// Handle trackpad pinch-to-zoom via PointerScaleEvent.
  void handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScaleEvent) return;

    // Amplify the scale delta for more responsive zoom
    final scaleDelta = event.scale - 1.0;
    final amplifiedScale = 1.0 + (scaleDelta * _trackpadZoomSensitivity);

    final newZoom = (zoomPanState.displaySettings.zoomLevel * amplifiedScale)
        .clamp(DisplaySettings.minZoom, DisplaySettings.maxZoom);

    setState(() {
      zoomPanState.displaySettings = zoomPanState.displaySettings.copyWith(
        zoomLevel: newZoom,
      );
    });

    onZoomChanged();
  }

  /// Builds a Listener and GestureDetector that handle zoom/pan gestures.
  Widget buildZoomPanGestureDetector({required Widget child}) {
    return Listener(
      onPointerSignal: handlePointerSignal,
      child: GestureDetector(
        onScaleStart: handleScaleStart,
        onScaleUpdate: handleScaleUpdate,
        onScaleEnd: handleScaleEnd,
        child: child,
      ),
    );
  }

  /// Builds Transform widgets that apply the current zoom and pan.
  Widget buildZoomPanTransform({required Widget child}) {
    return Transform.translate(
      offset: zoomPanState.panOffset,
      child: Transform.scale(
        scale: zoomPanState.displaySettings.zoomLevel,
        child: child,
      ),
    );
  }
}
