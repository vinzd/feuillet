import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/web_url_strategy.dart';

void main() {
  group('configureUrlStrategy', () {
    test('function exists and is callable', () {
      // The function should exist and not throw when called
      // On non-web platforms, it's a no-op
      expect(() => configureUrlStrategy(), returnsNormally);
    });

    test('can be called multiple times without error', () {
      // Should be idempotent
      expect(() {
        configureUrlStrategy();
        configureUrlStrategy();
        configureUrlStrategy();
      }, returnsNormally);
    });
  });
}
