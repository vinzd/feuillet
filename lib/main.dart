import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'services/file_watcher_service.dart';
import 'services/pdf_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Skip file system operations on web (for development iteration only)
  if (!kIsWeb) {
    // Initialize file watcher for Syncthing support
    await FileWatcherService.instance.startWatching();

    // Initialize PDF service
    PdfService.instance;
  }

  runApp(
    const ProviderScope(
      child: OpenScoreApp(),
    ),
  );
}

class OpenScoreApp extends StatelessWidget {
  const OpenScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Score',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AppLifecycleManager(child: HomeScreen()),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
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

  const AppLifecycleManager({
    super.key,
    required this.child,
  });

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Skip file system operations on web
    if (kIsWeb) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Restart file watching when app comes to foreground
        FileWatcherService.instance.startWatching();
        // Rescan library for changes made while app was in background
        PdfService.instance.scanAndSyncLibrary();
        break;
      case AppLifecycleState.paused:
        // Stop file watching when app goes to background to save resources
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
