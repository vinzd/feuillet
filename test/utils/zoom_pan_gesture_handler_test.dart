import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/utils/display_settings.dart';
import 'package:feuillet/utils/zoom_pan_gesture_handler.dart';

void main() {
  group('ZoomPanState', () {
    test('initializes with provided display settings', () {
      final state = ZoomPanState(
        displaySettings: const DisplaySettings(zoomLevel: 1.5),
      );

      expect(state.displaySettings.zoomLevel, 1.5);
      expect(state.panOffset, Offset.zero);
    });

    test('initializes with default pan offset of zero', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      expect(state.panOffset, Offset.zero);
    });

    test('initializes with custom pan offset', () {
      final state = ZoomPanState(
        displaySettings: DisplaySettings.defaults,
        panOffset: const Offset(10, 20),
      );

      expect(state.panOffset, const Offset(10, 20));
    });

    test('baseZoom is null initially', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      expect(state.baseZoom, isNull);
    });

    test('basePanOffset is null initially', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      expect(state.basePanOffset, isNull);
    });

    test('displaySettings can be updated', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      state.displaySettings = state.displaySettings.copyWith(zoomLevel: 2.0);

      expect(state.displaySettings.zoomLevel, 2.0);
    });

    test('panOffset can be updated', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      state.panOffset = const Offset(50, 100);

      expect(state.panOffset, const Offset(50, 100));
    });

    test('baseZoom can be set and cleared', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      state.baseZoom = 1.5;
      expect(state.baseZoom, 1.5);

      state.baseZoom = null;
      expect(state.baseZoom, isNull);
    });

    test('basePanOffset can be set and cleared', () {
      final state = ZoomPanState(displaySettings: DisplaySettings.defaults);

      state.basePanOffset = const Offset(20, 30);
      expect(state.basePanOffset, const Offset(20, 30));

      state.basePanOffset = null;
      expect(state.basePanOffset, isNull);
    });
  });

  group('ZoomPanGestureMixin', () {
    late _TestWidget testWidget;
    late _TestWidgetState testState;

    setUp(() {
      testWidget = const _TestWidget();
    });

    group('handleScaleStart', () {
      testWidgets('sets baseZoom to current zoom level', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 1.8);

        testState.handleScaleStart(ScaleStartDetails());

        expect(testState.zoomPanState.baseZoom, 1.8);
      });

      testWidgets('sets basePanOffset to current pan offset', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.zoomPanState.panOffset = const Offset(30, 40);

        testState.handleScaleStart(ScaleStartDetails());

        expect(testState.zoomPanState.basePanOffset, const Offset(30, 40));
      });
    });

    group('handleScaleUpdate', () {
      testWidgets('updates zoom level when scale changes', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.5,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );

        expect(testState.zoomPanState.displaySettings.zoomLevel, 1.5);
      });

      testWidgets('clamps zoom to minimum', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 0.1, // Would result in 0.1 zoom, below minimum
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );

        expect(
          testState.zoomPanState.displaySettings.zoomLevel,
          DisplaySettings.minZoom,
        );
      });

      testWidgets('clamps zoom to maximum', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 10.0, // Would result in 10.0 zoom, above maximum
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );

        expect(
          testState.zoomPanState.displaySettings.zoomLevel,
          DisplaySettings.maxZoom,
        );
      });

      testWidgets('does not update zoom when scale is 1.0', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 1.5);

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );

        // Zoom should remain unchanged
        expect(testState.zoomPanState.displaySettings.zoomLevel, 1.5);
      });

      testWidgets('updates pan offset when zoomed in', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 1.5);

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0, // No zoom change
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset(10, 20), // But there's pan
          ),
        );

        expect(testState.zoomPanState.panOffset, const Offset(10, 20));
      });

      testWidgets('does not update pan when at default zoom', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Zoom is 1.0 by default

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset(10, 20),
          ),
        );

        // Pan should remain at zero because zoom is 1.0
        expect(testState.zoomPanState.panOffset, Offset.zero);
      });

      testWidgets('does nothing when isZoomPanDisabled is true', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.setZoomPanDisabled(true);

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 2.0,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );

        // Zoom should remain at default because disabled
        expect(testState.zoomPanState.displaySettings.zoomLevel, 1.0);
      });

      testWidgets('does nothing when baseZoom is null', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Don't call handleScaleStart, so baseZoom is null
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 2.0,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );

        // Zoom should remain at default
        expect(testState.zoomPanState.displaySettings.zoomLevel, 1.0);
      });
    });

    group('handleScaleEnd', () {
      testWidgets('calls onZoomPanTap when no zoom or pan occurred', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        // No update - simulates a tap
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.tapCalled, isTrue);
        expect(testState.zoomChangedCalled, isFalse);
      });

      testWidgets('calls onZoomChanged when zoom occurred', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.5,
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset.zero,
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.tapCalled, isFalse);
        expect(testState.zoomChangedCalled, isTrue);
      });

      testWidgets('does not call onZoomChanged for pan-only gesture', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // First zoom in so pan is allowed
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 1.5);

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0, // No zoom change
            focalPoint: Offset.zero,
            localFocalPoint: Offset.zero,
            focalPointDelta: Offset(50, 50), // But there's pan
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.tapCalled, isFalse);
        expect(testState.zoomChangedCalled, isFalse);
      });

      testWidgets('resets pan when zoom returns to 1.0', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Set up a zoomed and panned state
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 1.0);
        testState.zoomPanState.panOffset = const Offset(100, 100);

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleEnd(ScaleEndDetails());

        // Pan should be reset because zoom is 1.0
        expect(testState.zoomPanState.panOffset, Offset.zero);
      });

      testWidgets('preserves pan when zoom is above 1.0', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Set up a zoomed and panned state
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 1.5);
        testState.zoomPanState.panOffset = const Offset(100, 100);

        testState.handleScaleStart(ScaleStartDetails());
        testState.handleScaleEnd(ScaleEndDetails());

        // Pan should be preserved because zoom > 1.0
        expect(testState.zoomPanState.panOffset, const Offset(100, 100));
      });

      testWidgets('clears baseZoom after gesture ends', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        expect(testState.zoomPanState.baseZoom, isNotNull);

        testState.handleScaleEnd(ScaleEndDetails());
        expect(testState.zoomPanState.baseZoom, isNull);
      });

      testWidgets('clears basePanOffset after gesture ends', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(ScaleStartDetails());
        expect(testState.zoomPanState.basePanOffset, isNotNull);

        testState.handleScaleEnd(ScaleEndDetails());
        expect(testState.zoomPanState.basePanOffset, isNull);
      });
    });

    group('handlePointerSignal', () {
      testWidgets('ignores non-PointerScaleEvent', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Create a scroll event instead of scale event
        final scrollEvent = PointerScrollEvent(
          position: Offset.zero,
          scrollDelta: const Offset(0, 10),
        );

        testState.handlePointerSignal(scrollEvent);

        // Zoom should remain unchanged
        expect(testState.zoomPanState.displaySettings.zoomLevel, 1.0);
      });

      testWidgets('amplifies scale delta for trackpad gestures', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Simulate a small trackpad pinch (scale 1.02)
        final scaleEvent = PointerScaleEvent(
          position: Offset.zero,
          scale: 1.02,
        );

        testState.handlePointerSignal(scaleEvent);

        // With 3x sensitivity: 1.0 + (0.02 * 3) = 1.06
        // So new zoom = 1.0 * 1.06 = 1.06
        expect(
          testState.zoomPanState.displaySettings.zoomLevel,
          closeTo(1.06, 0.001),
        );
      });

      testWidgets('clamps zoom to minimum on trackpad pinch in', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Start at minimum zoom
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: DisplaySettings.minZoom);

        // Try to zoom out further
        final scaleEvent = PointerScaleEvent(position: Offset.zero, scale: 0.5);

        testState.handlePointerSignal(scaleEvent);

        expect(
          testState.zoomPanState.displaySettings.zoomLevel,
          DisplaySettings.minZoom,
        );
      });

      testWidgets('clamps zoom to maximum on trackpad pinch out', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Start at maximum zoom
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: DisplaySettings.maxZoom);

        // Try to zoom in further
        final scaleEvent = PointerScaleEvent(position: Offset.zero, scale: 1.5);

        testState.handlePointerSignal(scaleEvent);

        expect(
          testState.zoomPanState.displaySettings.zoomLevel,
          DisplaySettings.maxZoom,
        );
      });

      testWidgets('calls onZoomChanged after trackpad zoom', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        final scaleEvent = PointerScaleEvent(position: Offset.zero, scale: 1.1);

        testState.handlePointerSignal(scaleEvent);

        expect(testState.zoomChangedCalled, isTrue);
      });
    });

    group('buildZoomPanGestureDetector', () {
      testWidgets('wraps child with Listener and GestureDetector', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));

        // Find the Listener
        expect(find.byType(Listener), findsWidgets);

        // Find the GestureDetector
        expect(find.byType(GestureDetector), findsWidgets);
      });
    });

    group('buildZoomPanTransform', () {
      testWidgets('applies Transform.translate with pan offset', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.zoomPanState.panOffset = const Offset(50, 100);

        await tester.pump();

        // The transforms are applied - verify the widget tree contains Transform
        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('applies Transform.scale with zoom level', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 2.0);

        await tester.pump();

        // The transforms are applied - verify the widget tree contains Transform
        expect(find.byType(Transform), findsWidgets);
      });
    });

    group('isZoomPanDisabled', () {
      testWidgets('returns false by default', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        expect(testState.isZoomPanDisabled, isFalse);
      });

      testWidgets('can be overridden to return true', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.setZoomPanDisabled(true);

        expect(testState.isZoomPanDisabled, isTrue);
      });
    });

    group('swipe detection when zoomed in', () {
      // Default test viewport is 800x600.
      // At zoom 2x: maxPanX = (2.0 - 1.0) * 800 / 2 = 400
      // Overscroll threshold is 80px.

      testWidgets('detects left swipe when panning past right boundary', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Zoom to 2x — maxPanX = 400
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 2.0);
        // Start at the right boundary
        testState.zoomPanState.panOffset = const Offset(-400, 0);

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(300, 200)),
        );
        // Drag left by 500px — 100 of that is overscroll past boundary (>= 80 threshold)
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: const Offset(-200, 200),
            localFocalPoint: const Offset(-200, 200),
            focalPointDelta: const Offset(-500, 0),
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.swipeLeftCalled, isTrue);
      });

      testWidgets('detects right swipe when panning past left boundary', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Zoom to 2x — maxPanX = 400
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 2.0);
        // Start at the left boundary
        testState.zoomPanState.panOffset = const Offset(400, 0);

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(100, 200)),
        );
        // Drag right by 500px — 100 of that is overscroll (>= 80 threshold)
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: const Offset(600, 200),
            localFocalPoint: const Offset(600, 200),
            focalPointDelta: const Offset(500, 0),
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.swipeRightCalled, isTrue);
      });

      testWidgets('does not swipe when overscroll is below threshold', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Zoom to 2x — maxPanX = 400
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 2.0);
        testState.zoomPanState.panOffset = const Offset(-400, 0);

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(300, 200)),
        );
        // Drag left by 30px — 30px overscroll, below 80px threshold
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: const Offset(270, 200),
            localFocalPoint: const Offset(270, 200),
            focalPointDelta: const Offset(-30, 0),
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.swipeLeftCalled, isFalse);
        expect(testState.swipeRightCalled, isFalse);
      });

      testWidgets('accumulates pan across multiple update events', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Zoom to 2x so pan is allowed — maxPanX = 400, maxPanY = 300
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 2.0);

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(200, 200)),
        );

        // Simulate multiple small drag events (like real touch input)
        for (var i = 0; i < 10; i++) {
          testState.handleScaleUpdate(
            ScaleUpdateDetails(
              scale: 1.0,
              focalPoint: Offset(200.0 + (i + 1) * 10, 200),
              localFocalPoint: Offset(200.0 + (i + 1) * 10, 200),
              focalPointDelta: const Offset(10, 0),
            ),
          );
        }

        // 10 updates * 10px each = 100px total pan
        expect(testState.zoomPanState.panOffset.dx, 100.0);
      });

      testWidgets(
        'triggers left swipe from accumulated overscroll across multiple events',
        (tester) async {
          await tester.pumpWidget(MaterialApp(home: testWidget));
          testState = tester.state(find.byType(_TestWidget));

          // Zoom to 2x — maxPanX = 400
          testState.zoomPanState.displaySettings = testState
              .zoomPanState
              .displaySettings
              .copyWith(zoomLevel: 2.0);
          // Start at the right boundary
          testState.zoomPanState.panOffset = const Offset(-400, 0);

          testState.handleScaleStart(
            ScaleStartDetails(focalPoint: const Offset(300, 200)),
          );

          // Simulate 20 small drag events past boundary (5px each = 100px total overscroll)
          for (var i = 0; i < 20; i++) {
            testState.handleScaleUpdate(
              ScaleUpdateDetails(
                scale: 1.0,
                focalPoint: Offset(300.0 - (i + 1) * 5, 200),
                localFocalPoint: Offset(300.0 - (i + 1) * 5, 200),
                focalPointDelta: const Offset(-5, 0),
              ),
            );
          }
          testState.handleScaleEnd(ScaleEndDetails());

          // 20 * 5px = 100px accumulated overscroll, exceeds 80px threshold
          expect(testState.swipeLeftCalled, isTrue);
        },
      );

      testWidgets(
        'triggers right swipe from accumulated overscroll across multiple events',
        (tester) async {
          await tester.pumpWidget(MaterialApp(home: testWidget));
          testState = tester.state(find.byType(_TestWidget));

          // Zoom to 2x — maxPanX = 400
          testState.zoomPanState.displaySettings = testState
              .zoomPanState
              .displaySettings
              .copyWith(zoomLevel: 2.0);
          // Start at the left boundary
          testState.zoomPanState.panOffset = const Offset(400, 0);

          testState.handleScaleStart(
            ScaleStartDetails(focalPoint: const Offset(100, 200)),
          );

          // Simulate 20 small drag events past boundary (5px each = 100px total overscroll)
          for (var i = 0; i < 20; i++) {
            testState.handleScaleUpdate(
              ScaleUpdateDetails(
                scale: 1.0,
                focalPoint: Offset(100.0 + (i + 1) * 5, 200),
                localFocalPoint: Offset(100.0 + (i + 1) * 5, 200),
                focalPointDelta: const Offset(5, 0),
              ),
            );
          }
          testState.handleScaleEnd(ScaleEndDetails());

          // 20 * 5px = 100px accumulated overscroll, exceeds 80px threshold
          expect(testState.swipeRightCalled, isTrue);
        },
      );

      testWidgets('clamps pan offset to content bounds', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        // Zoom to 2x — maxPanX = 400
        testState.zoomPanState.displaySettings = testState
            .zoomPanState
            .displaySettings
            .copyWith(zoomLevel: 2.0);
        testState.zoomPanState.panOffset = const Offset(0, 0);

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(200, 200)),
        );
        // Drag right by 600px — should be clamped to maxPan = 400
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: const Offset(800, 200),
            localFocalPoint: const Offset(800, 200),
            focalPointDelta: const Offset(600, 0),
          ),
        );

        // Pan should be clamped to maxPan
        expect(testState.zoomPanState.panOffset.dx, 400.0);
      });
    });

    group('swipe detection at 1x zoom', () {
      testWidgets(
        'detects left swipe (next page) from negative horizontal displacement',
        (tester) async {
          await tester.pumpWidget(MaterialApp(home: testWidget));
          testState = tester.state(find.byType(_TestWidget));

          // Simulate a left swipe: start at right, end at left
          testState.handleScaleStart(
            ScaleStartDetails(focalPoint: const Offset(300, 200)),
          );
          testState.handleScaleUpdate(
            ScaleUpdateDetails(
              scale: 1.0,
              focalPoint: const Offset(200, 200),
              localFocalPoint: const Offset(200, 200),
              focalPointDelta: const Offset(-100, 0),
            ),
          );
          testState.handleScaleEnd(ScaleEndDetails());

          expect(testState.swipeLeftCalled, isTrue);
          expect(testState.swipeRightCalled, isFalse);
          expect(testState.tapCalled, isFalse);
        },
      );

      testWidgets(
        'detects right swipe (previous page) from positive horizontal displacement',
        (tester) async {
          await tester.pumpWidget(MaterialApp(home: testWidget));
          testState = tester.state(find.byType(_TestWidget));

          testState.handleScaleStart(
            ScaleStartDetails(focalPoint: const Offset(100, 200)),
          );
          testState.handleScaleUpdate(
            ScaleUpdateDetails(
              scale: 1.0,
              focalPoint: const Offset(200, 200),
              localFocalPoint: const Offset(200, 200),
              focalPointDelta: const Offset(100, 0),
            ),
          );
          testState.handleScaleEnd(ScaleEndDetails());

          expect(testState.swipeRightCalled, isTrue);
          expect(testState.swipeLeftCalled, isFalse);
          expect(testState.tapCalled, isFalse);
        },
      );

      testWidgets(
        'does not detect swipe when displacement is below threshold',
        (tester) async {
          await tester.pumpWidget(MaterialApp(home: testWidget));
          testState = tester.state(find.byType(_TestWidget));

          testState.handleScaleStart(
            ScaleStartDetails(focalPoint: const Offset(200, 200)),
          );
          testState.handleScaleUpdate(
            ScaleUpdateDetails(
              scale: 1.0,
              focalPoint: const Offset(220, 200),
              localFocalPoint: const Offset(220, 200),
              focalPointDelta: const Offset(20, 0),
            ),
          );
          testState.handleScaleEnd(ScaleEndDetails());

          expect(testState.swipeLeftCalled, isFalse);
          expect(testState.swipeRightCalled, isFalse);
          expect(testState.tapCalled, isTrue); // Small movement = tap
        },
      );

      testWidgets('does not detect swipe during pinch zoom', (tester) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(300, 200)),
        );
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.5, // Pinch zoom happening
            focalPoint: const Offset(200, 200),
            localFocalPoint: const Offset(200, 200),
            focalPointDelta: const Offset(-100, 0),
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.swipeLeftCalled, isFalse);
        expect(testState.swipeRightCalled, isFalse);
      });

      testWidgets('does not detect swipe when isZoomPanDisabled', (
        tester,
      ) async {
        await tester.pumpWidget(MaterialApp(home: testWidget));
        testState = tester.state(find.byType(_TestWidget));

        testState.setZoomPanDisabled(true);

        testState.handleScaleStart(
          ScaleStartDetails(focalPoint: const Offset(300, 200)),
        );
        testState.handleScaleUpdate(
          ScaleUpdateDetails(
            scale: 1.0,
            focalPoint: const Offset(200, 200),
            localFocalPoint: const Offset(200, 200),
            focalPointDelta: const Offset(-100, 0),
          ),
        );
        testState.handleScaleEnd(ScaleEndDetails());

        expect(testState.swipeLeftCalled, isFalse);
        expect(testState.swipeRightCalled, isFalse);
      });
    });
  });
}

/// Test widget that uses the ZoomPanGestureMixin.
class _TestWidget extends StatefulWidget {
  const _TestWidget();

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with ZoomPanGestureMixin {
  @override
  late final ZoomPanState zoomPanState;

  bool _isZoomPanDisabled = false;
  bool tapCalled = false;
  bool zoomChangedCalled = false;
  bool swipeLeftCalled = false;
  bool swipeRightCalled = false;

  @override
  void initState() {
    super.initState();
    zoomPanState = ZoomPanState(displaySettings: DisplaySettings.defaults);
  }

  @override
  bool get isZoomPanDisabled => _isZoomPanDisabled;

  void setZoomPanDisabled(bool value) {
    setState(() {
      _isZoomPanDisabled = value;
    });
  }

  @override
  void onZoomPanTap() {
    tapCalled = true;
  }

  @override
  void onZoomChanged() {
    zoomChangedCalled = true;
  }

  @override
  void onSwipeLeft() {
    swipeLeftCalled = true;
  }

  @override
  void onSwipeRight() {
    swipeRightCalled = true;
  }

  @override
  Widget build(BuildContext context) {
    return buildZoomPanGestureDetector(
      child: buildZoomPanTransform(
        child: const SizedBox(width: 200, height: 200),
      ),
    );
  }
}
