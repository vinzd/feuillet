import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';
import '../models/database.dart' as db;

/// Keys for app settings stored in database
///
/// @deprecated since multi-root migration. Retained for v6→v7 migration only.
/// New code should use the RootDirectories table via [AppSettingsService].
class AppSettingKeys {
  static const pdfDirectoryPath = 'pdf_directory_path';
  static const pdfDirectoryBookmark = 'pdf_directory_bookmark';
}

/// In-memory representation of a root library directory row.
class RootDirectory {
  final int id;
  final String path;
  final String? bookmark;
  final bool isDefault;
  final int orderIndex;
  final DateTime createdAt;

  const RootDirectory({
    required this.id,
    required this.path,
    this.bookmark,
    required this.isDefault,
    required this.orderIndex,
    required this.createdAt,
  });

  factory RootDirectory.fromRow(db.RootDirectory row) {
    return RootDirectory(
      id: row.id,
      path: row.path,
      bookmark: row.bookmark,
      isDefault: row.isDefault,
      orderIndex: row.orderIndex,
      createdAt: row.createdAt,
    );
  }
}

/// Service for managing app-wide settings and the list of root library
/// directories.
///
/// The root directories are stored in the [db.RootDirectories] table.
/// Exactly one row should have `isDefault = true` — that row is the
/// destination for new imports.
class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  final _database = DatabaseService.instance.database;

  // ---------------------------------------------------------------------------
  // Multi-root directory API
  // ---------------------------------------------------------------------------

  /// Returns all root directories ordered by [orderIndex].
  ///
  /// If the table is empty (fresh install), lazily inserts the default
  /// platform-specific path so downstream code always sees at least one
  /// root. This preserves the legacy behaviour where the default was
  /// `<appDocDir>/feuillet/pdfs`.
  Future<List<RootDirectory>> getRootDirectories() async {
    if (kIsWeb) {
      // Web: return a hard-coded placeholder root without DB access.
      return [
        RootDirectory(
          id: 0,
          path: '/web_placeholder/pdfs',
          isDefault: true,
          orderIndex: 0,
          createdAt: _epoch,
        ),
      ];
    }

    final rows = await _database.getAllRootDirectories();
    if (rows.isEmpty) {
      final defaultPath = await _legacyDefaultPath();
      await _database.insertRootDirectory(
        db.RootDirectoriesCompanion(
          path: drift.Value(defaultPath),
          isDefault: const drift.Value(true),
          orderIndex: const drift.Value(0),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
      // On macOS, create a bookmark for the default path so we retain
      // access across launches.
      if (Platform.isMacOS) {
        await _createBookmark(defaultPath);
      }
      final refreshed = await _database.getAllRootDirectories();
      return refreshed.map(RootDirectory.fromRow).toList(growable: false);
    }
    return rows.map(RootDirectory.fromRow).toList(growable: false);
  }

  /// Returns the default root directory, inserting a fresh default if the
  /// table is empty. Never returns null on native platforms.
  Future<RootDirectory> getDefaultRootDirectory() async {
    final roots = await getRootDirectories();
    return roots.firstWhere((r) => r.isDefault, orElse: () => roots.first);
  }

  /// Returns the default root directory's path. Convenience wrapper.
  Future<String> getDefaultRootDirectoryPath() async {
    final root = await getDefaultRootDirectory();
    return root.path;
  }

  /// Adds a new root directory. The new root is *not* marked as default
  /// unless there are currently no other roots (i.e. the table was empty
  /// prior to this call).
  ///
  /// On macOS a secure-scoped bookmark is created for [path] and stored
  /// alongside the row.
  ///
  /// Returns the inserted [RootDirectory].
  Future<RootDirectory> addRootDirectory(String path) async {
    if (kIsWeb) {
      throw UnsupportedError('Cannot add root directory on web.');
    }

    final existing = await _database.getAllRootDirectories();
    final willBecomeDefault = existing.isEmpty;

    String? bookmark;
    if (Platform.isMacOS) {
      bookmark = await _createBookmark(path);
    }

    final id = await _database.insertRootDirectory(
      db.RootDirectoriesCompanion(
        path: drift.Value(path),
        bookmark: bookmark == null
            ? const drift.Value.absent()
            : drift.Value(bookmark),
        isDefault: drift.Value(willBecomeDefault),
        orderIndex: drift.Value(existing.length),
        createdAt: drift.Value(DateTime.now()),
      ),
    );

    final rows = await _database.getAllRootDirectories();
    final row = rows.firstWhere((r) => r.id == id);
    return RootDirectory.fromRow(row);
  }

  /// Removes a root directory by [id]. If [id] was the default, promotes
  /// the first remaining root to default (if any).
  Future<void> removeRootDirectory(int id) async {
    if (kIsWeb) return;

    final removed = (await _database.getAllRootDirectories())
        .where((r) => r.id == id)
        .firstOrNull;
    if (removed == null) return;

    // Stop accessing the macOS security-scoped resource if any.
    if (Platform.isMacOS && removed.bookmark != null) {
      await _stopAccessingPath(removed.path);
    }

    await _database.deleteRootDirectory(id);

    final remaining = await _database.getAllRootDirectories();
    if (removed.isDefault && remaining.isNotEmpty) {
      final nextDefault = remaining
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      await _database.setDefaultRootDirectory(nextDefault.first.id);
    }
  }

  /// Marks [id] as the default root directory (clearing the flag on all
  /// other roots).
  Future<void> setDefaultRootDirectory(int id) async {
    if (kIsWeb) return;
    await _database.setDefaultRootDirectory(id);
  }

  /// Watch the root directories list (e.g. for UI updates).
  Stream<List<RootDirectory>> watchRootDirectories() {
    return _database.watchAllRootDirectories().map(
      (rows) => rows.map(RootDirectory.fromRow).toList(growable: false),
    );
  }

  // ---------------------------------------------------------------------------
  // Backward-compatible single-path API (deprecated)
  // ---------------------------------------------------------------------------

  /// @deprecated Use [getDefaultRootDirectoryPath] instead.
  Future<String> getPdfDirectoryPath() async {
    return getDefaultRootDirectoryPath();
  }

  /// @deprecated Use [addRootDirectory] + [setDefaultRootDirectory] instead.
  ///
  /// Adds [path] as a new root directory and marks it as the default.
  /// This mimics the legacy single-root "set the directory" behaviour.
  Future<void> setPdfDirectoryPath(String path) async {
    final root = await addRootDirectory(path);
    await setDefaultRootDirectory(root.id);
  }

  /// @deprecated Use [removeRootDirectory] instead.
  ///
  /// Removes all root directories. The next call to [getRootDirectories]
  /// will lazily re-create the platform default root.
  Future<void> clearPdfDirectoryPath() async {
    if (kIsWeb) return;
    if (Platform.isMacOS) {
      final roots = await _database.getAllRootDirectories();
      for (final r in roots) {
        if (r.bookmark != null) await _stopAccessingPath(r.path);
      }
    }
    final roots = await _database.getAllRootDirectories();
    for (final r in roots) {
      await _database.deleteRootDirectory(r.id);
    }
  }

  /// @deprecated Use [getRootDirectories] and check whether any row has a
  /// non-default path. Returns `true` if at least one root directory is
  /// configured (and the platform is not web).
  Future<bool> isUsingCustomPdfDirectory() async {
    if (kIsWeb) return false;
    return (await _database.getAllRootDirectories()).isNotEmpty;
  }

  /// Invalidate any cached state. Safe to call after mutating the
  /// RootDirectories table from another path.
  void invalidateCache() {}

  // ---------------------------------------------------------------------------
  // macOS secure bookmarks
  // ---------------------------------------------------------------------------

  Future<String?> _createBookmark(String path) async {
    if (!Platform.isMacOS) return null;
    try {
      final secureBookmarks = SecureBookmarks();
      final bookmark = await secureBookmarks.bookmark(Directory(path));
      // Persist the bookmark in the row that matches this path.
      final rows =
          await (_database.select(_database.rootDirectories)
                ..where((r) => r.path.equals(path))
                ..limit(1))
              .get();
      if (rows.isNotEmpty) {
        await _database.updateRootDirectory(
          rows.first.copyWith(bookmark: drift.Value(bookmark)),
        );
      }
      await secureBookmarks.startAccessingSecurityScopedResource(
        Directory(path),
      );
      return bookmark;
    } catch (e) {
      debugPrint('AppSettingsService: Failed to create bookmark for $path: $e');
      return null;
    }
  }

  Future<void> _stopAccessingPath(String path) async {
    if (!Platform.isMacOS) return;
    try {
      await SecureBookmarks().stopAccessingSecurityScopedResource(
        Directory(path),
      );
    } catch (e) {
      debugPrint('AppSettingsService: Failed to stop accessing $path: $e');
    }
  }

  /// Calls [getPdfDirectoryPath] notifier-style helper; some callers (e.g.
  /// [FileWatcherService]) read both the list and the legacy single path.
  /// This is kept for source compatibility and forwards to the new API.
  Future<void> ensureDefaultRootExists() async {
    await getDefaultRootDirectory();
  }

  // ---------------------------------------------------------------------------
  // Default path computation (legacy)
  // ---------------------------------------------------------------------------

  /// The hard-coded default path that was previously returned when no
  /// custom directory was set. Used only to lazily seed the
  /// RootDirectories table on fresh installs.
  Future<String> _legacyDefaultPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, 'feuillet', 'pdfs');
  }

  // Validate the default root directory's path is accessible, falling back
  // to platform default if the mounted path no longer exists. This mirrors
  // the legacy bookmark verification path.
  //
  // We keep this for callers that read directory paths via the deprecated
  // [getPdfDirectoryPath] alias: it ensures the returned path still exists
  // on disk, or re-derives a default otherwise.
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
