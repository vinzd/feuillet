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
  Widget build(BuildContext context) {
    return buildZoomPanGestureDetector(
      child: buildZoomPanTransform(
        child: const SizedBox(width: 200, height: 200),
      ),
    );
  }
}
