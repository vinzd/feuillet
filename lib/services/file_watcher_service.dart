import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;

/// Service to monitor file system changes for Syncthing compatibility
/// Watches the database and PDF directory for external modifications
class FileWatcherService {
  FileWatcherService._();
  static final FileWatcherService instance = FileWatcherService._();

  DirectoryWatcher? _pdfDirectoryWatcher;
  FileWatcher? _databaseWatcher;

  final _pdfChangesController = StreamController<WatchEvent>.broadcast();
  final _databaseChangesController = StreamController<WatchEvent>.broadcast();

  bool _isWatching = false;
  String? _pdfDirectoryPath;
  String? _databasePath;

  /// Stream of PDF directory changes
  Stream<WatchEvent> get pdfChanges => _pdfChangesController.stream;

  /// Stream of database file changes
  Stream<WatchEvent> get databaseChanges => _databaseChangesController.stream;

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
      // Get the PDF directory path
      final appDocDir = await getApplicationDocumentsDirectory();
      _pdfDirectoryPath = p.join(appDocDir.path, 'open_score', 'pdfs');
      _databasePath =
          p.join(appDocDir.path, 'open_score', 'open_score_db.sqlite');

      // Create directories if they don't exist
      final pdfDir = Directory(_pdfDirectoryPath!);
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      // Start watching PDF directory
      await _startPdfDirectoryWatcher();

      // Start watching database file (if it exists)
      await _startDatabaseWatcher();

      _isWatching = true;
      debugPrint('FileWatcherService: Started watching');
      debugPrint('  PDF Directory: $_pdfDirectoryPath');
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
    if (!_isWatching) {
      return;
    }

    try {
      // Note: watcher package doesn't have explicit stop method
      // Watchers will be garbage collected
      _pdfDirectoryWatcher = null;
      _databaseWatcher = null;

      _isWatching = false;
      debugPrint('FileWatcherService: Stopped watching');
    } catch (e) {
      debugPrint('FileWatcherService: Error stopping watchers: $e');
    }
  }

  /// Restart watchers (useful after Syncthing sync)
  Future<void> restartWatching() async {
    await stopWatching();
    await Future.delayed(const Duration(milliseconds: 500));
    await startWatching();
  }

  /// Start watching the PDF directory
  Future<void> _startPdfDirectoryWatcher() async {
    if (_pdfDirectoryPath == null) return;

    try {
      _pdfDirectoryWatcher = DirectoryWatcher(_pdfDirectoryPath!);

      _pdfDirectoryWatcher!.events.listen(
        (event) {
          debugPrint(
              'FileWatcherService: PDF directory event: ${event.type} - ${event.path}');

          // Filter out temporary Syncthing files
          if (_isSyncthingTempFile(event.path)) {
            return;
          }

          // Only process PDF files
          if (p.extension(event.path).toLowerCase() == '.pdf') {
            _pdfChangesController.add(event);
          }
        },
        onError: (error) {
          debugPrint('FileWatcherService: PDF watcher error: $error');
        },
      );
    } catch (e) {
      debugPrint('FileWatcherService: Could not watch PDF directory: $e');
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

      _databaseWatcher!.events.listen(
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

  /// Get the PDF directory path
  Future<String> getPdfDirectoryPath() async {
    // Return a placeholder path on web (for development iteration only)
    if (kIsWeb) {
      return '/web_placeholder/pdfs';
    }

    if (_pdfDirectoryPath != null) {
      return _pdfDirectoryPath!;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    _pdfDirectoryPath = p.join(appDocDir.path, 'open_score', 'pdfs');

    // Create directory if it doesn't exist
    final pdfDir = Directory(_pdfDirectoryPath!);
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    return _pdfDirectoryPath!;
  }

  /// Get the database directory path (for Syncthing configuration)
  Future<String> getDatabaseDirectoryPath() async {
    // Return a placeholder path on web (for development iteration only)
    if (kIsWeb) {
      return '/web_placeholder';
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, 'open_score');
  }

  /// Dispose resources
  void dispose() {
    _pdfChangesController.close();
    _databaseChangesController.close();
    _pdfDirectoryWatcher = null;
    _databaseWatcher = null;
  }
}
