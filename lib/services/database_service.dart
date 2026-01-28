import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import 'file_watcher_service.dart';

/// Service to manage database lifecycle and handle external changes
class DatabaseService {
  DatabaseService._() {
    _initialize();
  }

  static final DatabaseService instance = DatabaseService._();

  AppDatabase? _database;
  StreamSubscription? _databaseChangesSubscription;

  final _reloadController = StreamController<void>.broadcast();

  /// Stream that emits when the database has been reloaded due to external changes
  Stream<void> get onReload => _reloadController.stream;

  /// Get the database instance (creates if needed)
  AppDatabase get database {
    _database ??= AppDatabase();
    return _database!;
  }

  /// Initialize the service and set up file watchers
  void _initialize() {
    // Listen to database file changes from Syncthing
    _databaseChangesSubscription = FileWatcherService.instance.databaseChanges.listen(
      _handleDatabaseChange,
      onError: (error) {
        debugPrint('DatabaseService: Error in database watcher: $error');
      },
    );
  }

  /// Handle database file changes detected by file watcher
  void _handleDatabaseChange(event) {
    debugPrint('DatabaseService: Database changed externally, preparing to reload');

    // Debounce multiple rapid changes (common with Syncthing)
    _debounceReload();
  }

  Timer? _reloadTimer;

  /// Debounce database reloads to avoid excessive reconnections
  void _debounceReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 1000), () {
      _reloadDatabase();
    });
  }

  /// Reload the database by closing and reopening the connection
  Future<void> _reloadDatabase() async {
    try {
      debugPrint('DatabaseService: Reloading database...');

      // Close the current database
      await _database?.close();

      // Create a new database instance
      _database = AppDatabase();

      // Notify listeners
      _reloadController.add(null);

      debugPrint('DatabaseService: Database reloaded successfully');
    } catch (e, stackTrace) {
      debugPrint('DatabaseService: Error reloading database: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Manually trigger a database reload (useful for testing or manual sync)
  Future<void> reload() async {
    await _reloadDatabase();
  }

  /// Close the database and clean up resources
  Future<void> dispose() async {
    _reloadTimer?.cancel();
    await _databaseChangesSubscription?.cancel();
    await _database?.close();
    _reloadController.close();
  }
}

/// Riverpod provider for the database
final databaseProvider = Provider<AppDatabase>((ref) {
  return DatabaseService.instance.database;
});

/// Provider for database reload stream
final databaseReloadProvider = StreamProvider<void>((ref) {
  return DatabaseService.instance.onReload;
});
