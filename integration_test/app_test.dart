import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:open_score/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('app launches and shows navigation', (WidgetTester tester) async {
      // Note: These tests require proper initialization of services
      // which may need to be mocked or configured for testing

      await tester.pumpWidget(const OpenScoreApp());
      await tester.pumpAndSettle();

      // Verify basic navigation is present
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Set Lists'), findsOneWidget);
    });

    testWidgets('can navigate between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const OpenScoreApp());
      await tester.pumpAndSettle();

      // Start on Library tab
      expect(find.text('Library'), findsOneWidget);

      // Tap Set Lists tab
      await tester.tap(find.text('Set Lists'));
      await tester.pumpAndSettle();

      // Should still show navigation
      expect(find.text('Set Lists'), findsOneWidget);

      // Go back to Library
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      expect(find.text('Library'), findsOneWidget);
    });

    // Note: More comprehensive integration tests would include:
    // - Testing PDF import flow
    // - Creating and managing set lists
    // - Drawing annotations
    // - Testing Syncthing file watching (with mock files)
    // - Testing performance mode navigation
    // - Testing settings persistence
    //
    // These require:
    // - Mock file system
    // - Test PDF files
    // - Proper database setup/teardown
    // - Service mocking or test implementations
  });
}
