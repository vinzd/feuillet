import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:feuillet/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'router/app_router.dart';
import 'services/database_service.dart';
import 'services/file_watcher_service.dart';
import 'services/document_service.dart';
import 'services/sync_service.dart';
import 'web_url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs on web (e.g., /document/3 instead of /#/document/3)
  configureUrlStrategy();

  // Skip file system operations on web (for development iteration only)
  if (!kIsWeb) {
    // Request storage permission on Android before any file access
    await requestStoragePermission();

    // Initialize file watcher for Syncthing support
    await FileWatcherService.instance.startWatching();

    // Initialize PDF service
    DocumentService.instance;

    // Initialize sync manager for Syncthing annotation/setlist sync
    final pdfDir = await FileWatcherService.instance.getPdfDirectoryPath();
    SyncManager.instance.startListening(
      syncChanges: FileWatcherService.instance.syncChanges,
      db: DatabaseService.instance.database,
      getPdfDirectoryPath: () =>
          FileWatcherService.instance.getPdfDirectoryPath(),
    );
    await SyncManager.instance.reconcileOnStartup(
      db: DatabaseService.instance.database,
      pdfDirectoryPath: pdfDir,
    );
  }

  runApp(const ProviderScope(child: FeuilletApp()));
}

/// Requests MANAGE_EXTERNAL_STORAGE permission on Android.
/// Must be called before any file access operations.
Future<void> requestStoragePermission() async {
  if (!kIsWeb && Platform.isAndroid) {
    final status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }
}

class FeuilletApp extends ConsumerWidget {
  const FeuilletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return AppLifecycleManager(
      child: MaterialApp.router(
        title: 'Feuillet',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }
}

/// Manages app lifecycle for file watching
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: _handleExitRequest,
      onStateChange: _handleStateChange,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Handle app exit request (desktop only) - allows async cleanup before exit.
  Future<AppExitResponse> _handleExitRequest() async {
    if (kIsWeb) return AppExitResponse.exit;

    debugPrint('AppLifecycleManager: Exit requested, cleaning up...');
    SyncManager.instance.dispose();
    await FileWatcherService.instance.dispose();
    DocumentService.instance.dispose();
    await DatabaseService.instance.dispose();
    debugPrint('AppLifecycleManager: Cleanup complete, exiting.');
    return AppExitResponse.exit;
  }

  /// Handle lifecycle state changes (background/foreground).
  void _handleStateChange(AppLifecycleState state) {
    if (kIsWeb) return;

    switch (state) {
      case AppLifecycleState.resumed:
        FileWatcherService.instance.startWatching();
        DocumentService.instance.scanAndSyncLibrary();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        FileWatcherService.instance.stopWatching();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
