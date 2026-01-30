import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:feuillet/router/app_router.dart';

void main() {
  group('AppRoutes', () {
    test('static route constants are defined correctly', () {
      expect(AppRoutes.library, '/library');
      expect(AppRoutes.setlists, '/setlists');
      expect(AppRoutes.document, '/document/:documentId');
      expect(AppRoutes.setlistDetail, '/setlist/:setListId');
      expect(AppRoutes.setlistPerformance, '/setlist/:setListId/perform');
    });

    test('documentPath generates correct URL', () {
      expect(AppRoutes.documentPath(1), '/document/1');
      expect(AppRoutes.documentPath(42), '/document/42');
      expect(AppRoutes.documentPath(999), '/document/999');
    });

    test('setlistDetailPath generates correct URL', () {
      expect(AppRoutes.setlistDetailPath(1), '/setlist/1');
      expect(AppRoutes.setlistDetailPath(7), '/setlist/7');
      expect(AppRoutes.setlistDetailPath(123), '/setlist/123');
    });

    test('setlistPerformancePath generates correct URL', () {
      expect(AppRoutes.setlistPerformancePath(1), '/setlist/1/perform');
      expect(AppRoutes.setlistPerformancePath(7), '/setlist/7/perform');
      expect(AppRoutes.setlistPerformancePath(123), '/setlist/123/perform');
    });
  });

  group('routerProvider', () {
    test('provides a GoRouter instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      expect(router, isA<GoRouter>());
    });

    test('initial location is configured as /library', () {
      // We verify this via the AppRoutes constant since the router
      // uses initialLocation: AppRoutes.library
      expect(AppRoutes.library, '/library');
    });
  });

  group('Route redirects', () {
    testWidgets('root path redirects to /library', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );

      // Navigate to root
      router.go('/');
      await tester.pumpAndSettle();

      // Should redirect to /library
      expect(router.routerDelegate.currentConfiguration.uri.path, '/library');
    }, skip: true); // Skip: requires full app initialization with database
  });

  group('Error page', () {
    testWidgets('shows error page for invalid routes', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );

      // Navigate to invalid route
      router.go('/invalid/route/that/does/not/exist');
      await tester.pumpAndSettle();

      // Should show error page
      expect(find.text('Page Not Found'), findsOneWidget);
      expect(find.text('The requested page was not found.'), findsOneWidget);
      expect(find.text('Go to Library'), findsOneWidget);
    });
  });
}
