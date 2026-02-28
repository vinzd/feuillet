import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/screens/wrappers/document_viewer_wrapper.dart';

void main() {
  group('documentByIdProvider', () {
    test('provider can be accessed with document ID', () {
      // Verify the provider family can create providers for different IDs
      final provider1 = documentByIdProvider(1);
      final provider2 = documentByIdProvider(42);

      // Each call with a different ID creates a different provider
      expect(provider1, isNot(same(provider2)));
    });
  });

  group('DocumentViewerWrapper', () {
    test('accepts documentId parameter', () {
      const wrapper = DocumentViewerWrapper(documentId: 42);
      expect(wrapper.documentId, 42);
    });

    test('accepts different document IDs', () {
      const wrapper1 = DocumentViewerWrapper(documentId: 1);
      const wrapper2 = DocumentViewerWrapper(documentId: 999);

      expect(wrapper1.documentId, 1);
      expect(wrapper2.documentId, 999);
    });

    // Note: Full widget tests are skipped because they require database
    // initialization and file system access which isn't available in tests.
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: DocumentViewerWrapper(documentId: 1)),
        ),
      );

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    }, skip: true); // Skip: requires database initialization

    testWidgets('shows error for non-existent document', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: DocumentViewerWrapper(documentId: 99999)),
        ),
      );

      await tester.pumpAndSettle();

      // Should show not found message
      expect(find.text('Document Not Found'), findsOneWidget);
      expect(find.text('This document could not be found.'), findsOneWidget);
      expect(find.text('Back to Library'), findsOneWidget);
    }, skip: true); // Skip: requires database initialization
  });
}
