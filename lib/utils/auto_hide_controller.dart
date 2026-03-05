import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Controller for auto-hiding UI controls after a period of inactivity.
///
/// Manages a timer that automatically hides controls after [duration]
/// seconds of inactivity. Call [resetTimer] to restart the timer
/// when the user interacts with the controls.
///
/// When controls are hidden (fullscreen mode), the device wake lock is
/// enabled to prevent the screen from sleeping during performances.
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

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Shows the controls and starts the auto-hide timer
  void show() {
    _isVisible = true;
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _setWakeLock(false);
    notifyListeners();
    resetTimer();
  }

  /// Hides the controls and cancels any pending timer
  void hide() {
    _hideTimer?.cancel();
    _isVisible = false;
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _setWakeLock(true);
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
        if (_isMobile) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        _setWakeLock(true);
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
    if (_isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _setWakeLock(false);
    super.dispose();
  }

  void _setWakeLock(bool enabled) {
    final future = enabled ? WakelockPlus.enable() : WakelockPlus.disable();
    // Wake lock is best-effort; ignore errors on unsupported platforms.
    future.ignore();
  }
}
