import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/setlist_detail_screen.dart';
import '../screens/setlists_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/wrappers/pdf_viewer_wrapper.dart';
import '../screens/wrappers/setlist_performance_wrapper.dart';
import '../widgets/error_placeholder_screen.dart';

/// Route path constants
class AppRoutes {
  static const library = '/library';
  static const setlists = '/setlists';
  static const settings = '/settings';
  static const document = '/document/:documentId';
  static const setlistDetail = '/setlist/:setListId';
  static const setlistPerformance = '/setlist/:setListId/perform';

  /// Generate path for a specific document
  static String documentPath(int id) => '/document/$id';

  /// Generate path for a specific set list detail
  static String setlistDetailPath(int id) => '/setlist/$id';

  /// Generate path for a specific set list performance
  static String setlistPerformancePath(int id) => '/setlist/$id/perform';
}

/// Provider for the app router
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.library,
    routes: [
      // Home with tabs using ShellRoute
      ShellRoute(
        builder: (context, state, child) {
          final isSetLists = state.uri.path.startsWith(AppRoutes.setlists);
          return HomeScreen(initialIndex: isSetLists ? 1 : 0, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.library,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LibraryScreen()),
          ),
          GoRoute(
            path: AppRoutes.setlists,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SetListsScreen()),
          ),
        ],
      ),

      // Document viewer
      GoRoute(
        path: AppRoutes.document,
        builder: (context, state) {
          final documentId = int.parse(state.pathParameters['documentId']!);
          return PdfViewerWrapper(documentId: documentId);
        },
      ),

      // Set list detail
      GoRoute(
        path: AppRoutes.setlistDetail,
        builder: (context, state) {
          final setListId = int.parse(state.pathParameters['setListId']!);
          return SetListDetailScreen(setListId: setListId);
        },
      ),

      // Set list performance
      GoRoute(
        path: AppRoutes.setlistPerformance,
        builder: (context, state) {
          final setListId = int.parse(state.pathParameters['setListId']!);
          return SetListPerformanceWrapper(setListId: setListId);
        },
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // Redirect root to library
    redirect: (context, state) {
      if (state.uri.path == '/') {
        return AppRoutes.library;
      }
      return null;
    },

    // Error handling for invalid routes
    errorBuilder: (context, state) => ErrorPlaceholderScreen(
      title: 'Page Not Found',
      message: 'The requested page was not found.',
      icon: Icons.error_outline,
      buttonLabel: 'Go to Library',
      navigateTo: AppRoutes.library,
    ),
  );
});
