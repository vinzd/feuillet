import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;
import '../models/database.dart';
import 'app_settings_service.dart';

/// Service to monitor file system changes for Syncthing compatibility
/// Watches the database and PDF directory for external modifications.
///
/// Supports multiple root library directories — one [DirectoryWatcher] is
/// created per configured root (see [AppSettingsService.getRootDirectories]).
class FileWatcherService {
  FileWatcherService._();
  static final FileWatcherService instance = FileWatcherService._();

  // Per-root watcher state. Indices are aligned across the three lists.
  final List<DirectoryWatcher?> _pdfDirectoryWatchers = [];
  final List<StreamSubscription?> _pdfWatcherSubscriptions = [];
  final List<String> _pdfDirectoryPaths = [];

  FileWatcher? _databaseWatcher;
  StreamSubscription? _databaseWatcherSubscription;

  final _pdfChangesController = StreamController<WatchEvent>.broadcast();
  final _databaseChangesController = StreamController<WatchEvent>.broadcast();
  final _syncChangesController = StreamController<WatchEvent>.broadcast();

  bool _isWatching = false;
  String? _databasePath;

  /// Stream of PDF directory changes (aggregated across all roots).
  Stream<WatchEvent> get pdfChanges => _pdfChangesController.stream;

  /// Stream of database file changes
  Stream<WatchEvent> get databaseChanges => _databaseChangesController.stream;

  /// Stream of sidecar and set list file changes (aggregated across roots).
  Stream<WatchEvent> get syncChanges => _syncChangesController.stream;

  /// Check if a file is a sidecar metadata file
  static bool isSidecarFile(String fileName) =>
      fileName.endsWith('.feuillet.json');

  /// Check if a file is a set list file
  static bool isSetListFile(String fileName) =>
      fileName.endsWith('.setlist.json');

  /// Check if the watcher is currently active
  bool get isWatching => _isWatching;

  /// Initialize and start watching files
  ///
  /// This should be called when the app starts and resumed from background
  Future<void> startWatching() async {
    // Skip on web platform (for development iteration only)
    if (kIsWeb) {
      debugPrint('FileWatcherService: Skipping on web platform');
      return;
    }

    if (_isWatching) {
      debugPrint('FileWatcherService: Already watching');
      return;
    }

    try {
      // Get the configured root directories (lazily seeds default).
      final roots = await AppSettingsService.instance.getRootDirectories();
      final rootPaths = roots.map((r) => r.path).toList(growable: false);
      _pdfDirectoryPaths.clear();

      // Database path always stays in app documents
      final appDocDir = await getApplicationDocumentsDirectory();
      _databasePath = p.join(appDocDir.path, 'feuillet', 'feuillet_db.sqlite');

      // Start watcher for each root directory
      for (final rootPath in rootPaths) {
        final pdfDir = Directory(rootPath);
        if (!await pdfDir.exists()) {
          await pdfDir.create(recursive: true);
        }
        await _startPdfDirectoryWatcher(rootPath);
      }

      // Start watching database file (if it exists)
      await _startDatabaseWatcher();

      _isWatching = true;
      debugPrint('FileWatcherService: Started watching');
      debugPrint('  Root directories: $_pdfDirectoryPaths');
      debugPrint('  Database: $_databasePath');
    } catch (e, stackTrace) {
      debugPrint('FileWatcherService: Error starting watchers: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Stop watching files
  ///
  /// This should be called when the app is paused or goes to background
  Future<void> stopWatching() async {
    if (!_isWatching) return;

    for (final sub in _pdfWatcherSubscriptions) {
      await sub?.cancel();
    }
    await _databaseWatcherSubscription?.cancel();

    _pdfWatcherSubscriptions.clear();
    _pdfDirectoryWatchers.clear();
    _pdfDirectoryPaths.clear();
    _databaseWatcherSubscription = null;
    _databaseWatcher = null;

    _isWatching = false;
    debugPrint('FileWatcherService: Stopped watching');
  }

  /// Restart watchers (useful after Syncthing sync)
  Future<void> restartWatching() async {
    await stopWatching();
    await Future.delayed(const Duration(milliseconds: 500));
    await startWatching();
  }

  /// Restart all watchers using the latest root directories from settings.
  /// Call this after [AppSettingsService.addRootDirectory] /
  /// [removeRootDirectory] / [setDefaultRootDirectory].
  Future<void> updateRootDirectories() async {
    AppSettingsService.instance.invalidateCache();
    await restartWatching();
  }

  /// Start watching a single PDF root directory
  Future<void> _startPdfDirectoryWatcher(String rootPath) async {
    if (rootPath.isEmpty) return;

    try {
      final watcher = DirectoryWatcher(rootPath);
      final subscription = watcher.events.listen(
        (event) {
          debugPrint(
            'FileWatcherService: PDF directory event: ${event.type} - ${event.path}',
          );

          // Filter out temporary Syncthing files
          if (_isSyncthingTempFile(event.path)) {
            return;
          }

          // Sidecar and set list files
          final fileName = p.basename(event.path);
          if (isSidecarFile(fileName) || isSetListFile(fileName)) {
            _syncChangesController.add(event);
            return;
          }

          // Document files
          final ext = p.extension(event.path).toLowerCase().replaceAll('.', '');
          if (DocumentTypes.allExtensions.contains(ext)) {
            _pdfChangesController.add(event);
          }
        },
        onError: (error) {
          debugPrint('FileWatcherService: PDF watcher error: $error');
        },
      );

      _pdfDirectoryWatchers.add(watcher);
      _pdfWatcherSubscriptions.add(subscription);
      _pdfDirectoryPaths.add(rootPath);
    } catch (e) {
      debugPrint('FileWatcherService: Could not watch PDF directory: $e');
      // Keep list lengths aligned even on failure.
      _pdfDirectoryWatchers.add(null);
      _pdfWatcherSubscriptions.add(null);
      _pdfDirectoryPaths.add(rootPath);
    }
  }

  /// Start watching the database file
  Future<void> _startDatabaseWatcher() async {
    if (_databasePath == null) return;

    try {
      final dbFile = File(_databasePath!);
      if (!await dbFile.exists()) {
        debugPrint('FileWatcherService: Database file does not exist yet');
        return;
      }

      _databaseWatcher = FileWatcher(_databasePath!);

      _databaseWatcherSubscription = _databaseWatcher!.events.listen(
        (event) {
          debugPrint('FileWatcherService: Database event: ${event.type}');

          // Filter out WAL and SHM files
          if (event.path.endsWith('-wal') || event.path.endsWith('-shm')) {
            return;
          }

          _databaseChangesController.add(event);
        },
        onError: (error) {
          debugPrint('FileWatcherService: Database watcher error: $error');
        },
      );
    } catch (e) {
      debugPrint('FileWatcherService: Could not watch database: $e');
    }
  }

  /// Check if a file is a Syncthing temporary file
  bool _isSyncthingTempFile(String path) {
    final fileName = p.basename(path);
    // Syncthing uses .tmp extensions or ~syncthing~ prefix
    return fileName.startsWith('.syncthing.') ||
        fileName.startsWith('~syncthing~') ||
        fileName.endsWith('.tmp') ||
        fileName.startsWith('.~');
  }

  /// Get the default PDF root directory path (from settings).
  ///
  /// Preserved for backward compatibility; new code should prefer
  /// [getPdfDirectoryPaths] or [AppSettingsService.getDefaultRootDirectoryPath].
  Future<String> getPdfDirectoryPath() async {
    if (kIsWeb) return '/web_placeholder/pdfs';
    return AppSettingsService.instance.getDefaultRootDirectoryPath();
  }

  /// Get all configured root directory paths (cached from startWatching).
  ///
  /// If watching is not active, falls back to reading from settings.
  Future<List<String>> getPdfDirectoryPaths() async {
    if (kIsWeb) return const ['/web_placeholder/pdfs'];
    if (_pdfDirectoryPaths.isNotEmpty) {
      return List.unmodifiable(_pdfDirectoryPaths);
    }
    final roots = await AppSettingsService.instance.getRootDirectories();
    return roots.map((r) => r.path).toList(growable: false);
  }

  /// Update the watched directory list and restart watching.
  /// @deprecated alias for [updateRootDirectories], kept for source
  /// compatibility with existing callers (settings/library screens).
  Future<void> updatePdfDirectoryPath() async {
    await updateRootDirectories();
  }

  /// Get the database directory path (for Syncthing configuration)
  Future<String> getDatabaseDirectoryPath() async {
    if (kIsWeb) return '/web_placeholder';
    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, 'feuillet');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopWatching();
    _pdfChangesController.close();
    _databaseChangesController.close();
    _syncChangesController.close();
  }
}
