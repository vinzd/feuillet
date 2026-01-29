import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/utils/auto_hide_controller.dart';

void main() {
  group('AutoHideController', () {
    test('defaults to visible', () {
      final controller = AutoHideController();
      addTearDown(controller.dispose);

      expect(controller.isVisible, isTrue);
    });

    test('can be initialized as hidden', () {
      final controller = AutoHideController(initiallyVisible: false);
      addTearDown(controller.dispose);

      expect(controller.isVisible, isFalse);
    });

    test('custom duration is stored', () {
      final controller = AutoHideController(
        duration: const Duration(seconds: 5),
      );
      addTearDown(controller.dispose);

      expect(controller.duration, const Duration(seconds: 5));
    });

    group('show', () {
      test('makes controls visible', () {
        final controller = AutoHideController(initiallyVisible: false);
        addTearDown(controller.dispose);

        controller.show();

        expect(controller.isVisible, isTrue);
      });

      test('notifies listeners', () {
        final controller = AutoHideController(initiallyVisible: false);
        addTearDown(controller.dispose);

        var notified = false;
        controller.addListener(() => notified = true);

        controller.show();

        expect(notified, isTrue);
      });
    });

    group('hide', () {
      test('makes controls hidden', () {
        final controller = AutoHideController();
        addTearDown(controller.dispose);

        controller.hide();

        expect(controller.isVisible, isFalse);
      });

      test('notifies listeners', () {
        final controller = AutoHideController();
        addTearDown(controller.dispose);

        var notified = false;
        controller.addListener(() => notified = true);

        controller.hide();

        expect(notified, isTrue);
      });
    });

    group('toggle', () {
      test('hides when visible', () {
        final controller = AutoHideController();
        addTearDown(controller.dispose);

        controller.toggle();

        expect(controller.isVisible, isFalse);
      });

      test('shows when hidden', () {
        final controller = AutoHideController(initiallyVisible: false);
        addTearDown(controller.dispose);

        controller.toggle();

        expect(controller.isVisible, isTrue);
      });

      test('notifies listeners', () {
        final controller = AutoHideController();
        addTearDown(controller.dispose);

        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.toggle();
        controller.toggle();

        expect(notifyCount, 2);
      });
    });

    group('auto-hide timer', () {
      testWidgets('hides after duration when visible', (tester) async {
        final controller = AutoHideController(
          duration: const Duration(milliseconds: 100),
        );
        addTearDown(controller.dispose);

        controller.show();
        expect(controller.isVisible, isTrue);

        await tester.pump(const Duration(milliseconds: 150));

        expect(controller.isVisible, isFalse);
      });

      testWidgets('resetTimer restarts the countdown', (tester) async {
        final controller = AutoHideController(
          duration: const Duration(milliseconds: 100),
        );
        addTearDown(controller.dispose);

        controller.show();

        // Wait 50ms then reset
        await tester.pump(const Duration(milliseconds: 50));
        controller.resetTimer();

        // Wait another 75ms (total 125ms from original show)
        await tester.pump(const Duration(milliseconds: 75));

        // Should still be visible because timer was reset
        expect(controller.isVisible, isTrue);

        // Wait remaining 50ms
        await tester.pump(const Duration(milliseconds: 50));

        // Now should be hidden
        expect(controller.isVisible, isFalse);
      });

      testWidgets('cancelTimer prevents hiding', (tester) async {
        final controller = AutoHideController(
          duration: const Duration(milliseconds: 100),
        );
        addTearDown(controller.dispose);

        controller.show();
        controller.cancelTimer();

        await tester.pump(const Duration(milliseconds: 150));

        expect(controller.isVisible, isTrue);
      });

      testWidgets('hide cancels pending timer', (tester) async {
        final controller = AutoHideController(
          duration: const Duration(milliseconds: 100),
        );
        addTearDown(controller.dispose);

        controller.show();
        controller.hide();

        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        // Wait for the original timer to expire
        await tester.pump(const Duration(milliseconds: 150));

        // Should not have been notified again since timer was cancelled
        expect(notifyCount, 0);
      });

      test('resetTimer has no effect when hidden', () {
        final controller = AutoHideController(initiallyVisible: false);
        addTearDown(controller.dispose);

        // This should not throw or start a timer
        controller.resetTimer();

        expect(controller.isVisible, isFalse);
      });
    });

    test('dispose cancels timer', () async {
      final controller = AutoHideController(
        duration: const Duration(milliseconds: 100),
      );

      controller.show();
      controller.dispose();

      // Should not throw even after dispose
    });
  });
}
