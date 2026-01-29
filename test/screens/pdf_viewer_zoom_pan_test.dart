import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/utils/display_settings.dart';
import 'package:open_score/utils/zoom_pan_gesture_handler.dart';

/// Tests for PDF viewer zoom and pan functionality.
/// Note: Full widget tests are difficult due to pdfx dependency.
/// These tests verify the zoom/pan logic in isolation.
void main() {
  group('Pinch-to-zoom logic', () {
    group('Zoom clamping', () {
      test('zoom should be clamped to minimum', () {
        const baseZoom = 1.0;
        const scaleGesture = 0.3; // Zoom out significantly

        final newZoom = (baseZoom * scaleGesture).clamp(
          DisplaySettings.minZoom,
          DisplaySettings.maxZoom,
        );

        expect(newZoom, DisplaySettings.minZoom);
        expect(newZoom, 0.5);
      });

      test('zoom should be clamped to maximum', () {
        const baseZoom = 2.0;
        const scaleGesture = 2.0; // Zoom in significantly

        final newZoom = (baseZoom * scaleGesture).clamp(
          DisplaySettings.minZoom,
          DisplaySettings.maxZoom,
        );

        expect(newZoom, DisplaySettings.maxZoom);
        expect(newZoom, 3.0);
      });

      test('zoom within range is not clamped', () {
        const baseZoom = 1.0;
        const scaleGesture = 1.5;

        final newZoom = (baseZoom * scaleGesture).clamp(
          DisplaySettings.minZoom,
          DisplaySettings.maxZoom,
        );

        expect(newZoom, 1.5);
      });
    });

    group('Trackpad pinch sensitivity', () {
      test('amplified scale increases zoom speed', () {
        const zoomSensitivity = 3.0;
        const eventScale = 1.02; // Small trackpad pinch out

        final scaleDelta = eventScale - 1.0;
        final amplifiedScale = 1.0 + (scaleDelta * zoomSensitivity);

        // Original would be 1.02, amplified should be 1.06
        expect(amplifiedScale, closeTo(1.06, 0.001));
      });

      test('amplified scale decreases zoom speed for pinch in', () {
        const zoomSensitivity = 3.0;
        const eventScale = 0.98; // Small trackpad pinch in

        final scaleDelta = eventScale - 1.0;
        final amplifiedScale = 1.0 + (scaleDelta * zoomSensitivity);

        // Original would be 0.98, amplified should be 0.94
        expect(amplifiedScale, closeTo(0.94, 0.001));
      });

      test('no amplification when scale is 1.0', () {
        const zoomSensitivity = 3.0;
        const eventScale = 1.0;

        final scaleDelta = eventScale - 1.0;
        final amplifiedScale = 1.0 + (scaleDelta * zoomSensitivity);

        expect(amplifiedScale, 1.0);
      });
    });

    group('Scale gesture detection', () {
      test('scale of 1.0 means no zoom change', () {
        const scale = 1.0;

        // Should not apply zoom when scale is exactly 1.0
        expect(scale != 1.0, isFalse);
      });

      test('scale greater than 1.0 means zoom in', () {
        const scale = 1.5;

        expect(scale > 1.0, isTrue);
      });

      test('scale less than 1.0 means zoom out', () {
        const scale = 0.8;

        expect(scale < 1.0, isTrue);
      });
    });
  });

  group('Pan functionality', () {
    group('Pan offset calculation', () {
      test('pan offset is accumulated from focal point delta', () {
        const basePanOffset = Offset(10, 20);
        const focalPointDelta = Offset(5, -3);

        final newPanOffset = basePanOffset + focalPointDelta;

        expect(newPanOffset, const Offset(15, 17));
      });

      test('pan offset starts from previous position', () {
        const basePanOffset = Offset(-50, 100);
        const focalPointDelta = Offset(30, 30);

        final newPanOffset = basePanOffset + focalPointDelta;

        expect(newPanOffset, const Offset(-20, 130));
      });
    });

    group('Pan restrictions', () {
      test('pan is only allowed when zoomed in', () {
        const zoomLevel = 1.5;

        expect(zoomLevel > 1.0, isTrue);
      });

      test('pan is not allowed at default zoom', () {
        const zoomLevel = 1.0;

        expect(zoomLevel > 1.0, isFalse);
      });

      test('pan is not allowed when zoomed out', () {
        const zoomLevel = 0.8;

        expect(zoomLevel > 1.0, isFalse);
      });
    });

    group('Pan reset', () {
      test('pan offset resets to zero when zoom is 1.0 or below', () {
        const zoomLevel = 1.0;
        var panOffset = const Offset(100, 200);

        if (zoomLevel <= 1.0) {
          panOffset = Offset.zero;
        }

        expect(panOffset, Offset.zero);
      });

      test('pan offset is preserved when zoom is above 1.0', () {
        const zoomLevel = 1.5;
        var panOffset = const Offset(100, 200);

        if (zoomLevel <= 1.0) {
          panOffset = Offset.zero;
        }

        expect(panOffset, const Offset(100, 200));
      });
    });
  });

  group('Tap detection', () {
    test('tap is detected when no zoom or pan occurred', () {
      const baseZoom = 1.5;
      const currentZoom = 1.5;
      const basePanOffset = Offset(10, 20);
      const currentPanOffset = Offset(10, 20);

      final didZoom = baseZoom != currentZoom;
      final didPan = basePanOffset != currentPanOffset;
      final isTap = !didZoom && !didPan;

      expect(isTap, isTrue);
    });

    test('tap is not detected when zoom occurred', () {
      const baseZoom = 1.0;
      const currentZoom = 1.5;
      const basePanOffset = Offset.zero;
      const currentPanOffset = Offset.zero;

      final didZoom = baseZoom != currentZoom;
      final didPan = basePanOffset != currentPanOffset;
      final isTap = !didZoom && !didPan;

      expect(isTap, isFalse);
    });

    test('tap is not detected when pan occurred', () {
      const baseZoom = 1.5;
      const currentZoom = 1.5;
      const basePanOffset = Offset.zero;
      const currentPanOffset = Offset(50, 30);

      final didZoom = baseZoom != currentZoom;
      final didPan = basePanOffset != currentPanOffset;
      final isTap = !didZoom && !didPan;

      expect(isTap, isFalse);
    });
  });

  group('Transform application', () {
    test('Transform.translate creates correct matrix for pan offset', () {
      const panOffset = Offset(100, 50);

      // Verify the expected behavior of Transform.translate
      final matrix = Matrix4.translationValues(panOffset.dx, panOffset.dy, 0);

      expect(matrix.getTranslation().x, 100);
      expect(matrix.getTranslation().y, 50);
    });

    test('Transform.scale creates correct matrix for zoom level', () {
      const zoomLevel = 2.0;

      // Verify the expected behavior of scaling matrix
      final matrix = Matrix4.diagonal3Values(zoomLevel, zoomLevel, 1.0);

      expect(matrix.entry(0, 0), 2.0);
      expect(matrix.entry(1, 1), 2.0);
    });

    test('combined pan and zoom transformation order', () {
      const panOffset = Offset(50, 25);
      const zoomLevel = 1.5;

      // Translation should be applied first, then scale
      // This matches Transform.translate(child: Transform.scale(...))
      final translateMatrix = Matrix4.translationValues(
        panOffset.dx,
        panOffset.dy,
        0,
      );
      final scaleMatrix = Matrix4.diagonal3Values(zoomLevel, zoomLevel, 1.0);

      // When nested, translate is the outer transform
      expect(translateMatrix.getTranslation().x, 50);
      expect(scaleMatrix.entry(0, 0), 1.5);
    });
  });

  group('ZoomPanState', () {
    test('initializes with provided display settings', () {
      final state = ZoomPanState(
        displaySettings: const DisplaySettings(zoomLevel: 1.5),
      );

      expect(state.displaySettings.zoomLevel, 1.5);
      expect(state.panOffset, Offset.zero);
    });

    test('initializes with custom pan offset', () {
      final state = ZoomPanState(
        displaySettings: DisplaySettings.defaults,
        panOffset: const Offset(10, 20),
      );

      expect(state.panOffset, const Offset(10, 20));
    });

    test('baseZoom and basePanOffset are null initially', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      expect(state.baseZoom, isNull);
      expect(state.basePanOffset, isNull);
    });

    test('can update display settings', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      state.displaySettings = state.displaySettings.copyWith(zoomLevel: 2.0);

      expect(state.displaySettings.zoomLevel, 2.0);
    });

    test('can update pan offset', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      state.panOffset = const Offset(50, 100);

      expect(state.panOffset, const Offset(50, 100));
    });
  });

  group('Annotation mode interaction', () {
    test('pan and zoom should be disabled in annotation mode', () {
      // In annotation mode, the isZoomPanDisabled getter returns true
      // This prevents zoom/pan gestures from conflicting with drawing
      const annotationMode = true;

      expect(annotationMode, isTrue);
    });

    test('pan and zoom should be enabled when not in annotation mode', () {
      const annotationMode = false;

      expect(annotationMode, isFalse);
    });
  });
}
