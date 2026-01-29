import 'dart:async';

import 'package:flutter/foundation.dart';

/// Controller for auto-hiding UI controls after a period of inactivity.
///
/// Manages a timer that automatically hides controls after [duration]
/// seconds of inactivity. Call [resetTimer] to restart the timer
/// when the user interacts with the controls.
class AutoHideController extends ChangeNotifier {
  AutoHideController({
    this.duration = const Duration(seconds: 3),
    bool initiallyVisible = true,
  }) : _isVisible = initiallyVisible;

  /// Duration before controls are automatically hidden
  final Duration duration;

  Timer? _hideTimer;
  bool _isVisible;

  /// Whether the controls are currently visible
  bool get isVisible => _isVisible;

  /// Shows the controls and starts the auto-hide timer
  void show() {
    _isVisible = true;
    notifyListeners();
    resetTimer();
  }

  /// Hides the controls and cancels any pending timer
  void hide() {
    _hideTimer?.cancel();
    _isVisible = false;
    notifyListeners();
  }

  /// Toggles controls visibility.
  ///
  /// If becoming visible, starts the auto-hide timer.
  void toggle() {
    _isVisible ? hide() : show();
  }

  /// Resets the auto-hide timer.
  ///
  /// Call this when the user interacts with the controls to prevent
  /// them from being hidden. Only has an effect if controls are visible.
  void resetTimer() {
    _hideTimer?.cancel();
    if (_isVisible) {
      _hideTimer = Timer(duration, () {
        _isVisible = false;
        notifyListeners();
      });
    }
  }

  /// Cancels the auto-hide timer without changing visibility.
  ///
  /// Use this when the user is actively interacting with a slider
  /// or other continuous input.
  void cancelTimer() {
    _hideTimer?.cancel();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}
