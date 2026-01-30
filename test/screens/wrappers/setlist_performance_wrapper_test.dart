import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/screens/wrappers/setlist_performance_wrapper.dart';

void main() {
  group('setListWithDocumentsProvider', () {
    test('provider can be accessed with set list ID', () {
      // Verify the provider family can create providers for different IDs
      final provider1 = setListWithDocumentsProvider(1);
      final provider2 = setListWithDocumentsProvider(7);

      // Each call with a different ID creates a different provider
      expect(provider1, isNot(same(provider2)));
    });
  });

  group('SetListPerformanceWrapper', () {
    test('accepts setListId parameter', () {
      const wrapper = SetListPerformanceWrapper(setListId: 7);
      expect(wrapper.setListId, 7);
    });

    test('accepts different set list IDs', () {
      const wrapper1 = SetListPerformanceWrapper(setListId: 1);
      const wrapper2 = SetListPerformanceWrapper(setListId: 123);

      expect(wrapper1.setListId, 1);
      expect(wrapper2.setListId, 123);
    });

    // Note: Full widget tests are skipped because they require database
    // initialization and file system access which isn't available in tests.
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SetListPerformanceWrapper(setListId: 1)),
        ),
      );

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    }, skip: true); // Skip: requires database initialization

    testWidgets('shows error for non-existent set list', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SetListPerformanceWrapper(setListId: 99999)),
        ),
      );

      await tester.pumpAndSettle();

      // Should show not found message
      expect(find.text('Set List Not Found'), findsOneWidget);
      expect(find.text('This set list could not be found.'), findsOneWidget);
      expect(find.text('Back to Set Lists'), findsOneWidget);
    }, skip: true); // Skip: requires database initialization

    testWidgets('shows empty state for set list without documents', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SetListPerformanceWrapper(setListId: 1)),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('This set list has no documents.'), findsOneWidget);
      expect(find.text('Edit Set List'), findsOneWidget);
    }, skip: true); // Skip: requires database initialization with mock data
  });
}
