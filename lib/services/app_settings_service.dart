import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';
import 'file_access_service.dart';

/// Keys for app settings stored in database
class AppSettingKeys {
  static const pdfDirectoryPath = 'pdf_directory_path';
  static const pdfDirectoryBookmark = 'pdf_directory_bookmark';
}

/// Service for managing app-wide settings
class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  final _database = DatabaseService.instance.database;

  /// Cached PDF directory path for performance
  String? _cachedPdfPath;

  /// Whether we've already resolved the bookmark this session
  bool _bookmarkResolved = false;

  /// Get the configured PDF directory path, or default if not set
  Future<String> getPdfDirectoryPath() async {
    if (kIsWeb) {
      return '/web_placeholder/pdfs';
    }

    // Return cached value if available
    if (_cachedPdfPath != null) {
      return _cachedPdfPath!;
    }

    // Check database for custom path
    final customPath = await _database.getAppSetting(
      AppSettingKeys.pdfDirectoryPath,
    );

    if (customPath != null && customPath.isNotEmpty) {
      // On macOS, resolve the security-scoped bookmark to regain access
      if (Platform.isMacOS && !_bookmarkResolved) {
        await _resolveBookmark();
      }

      // Verify the directory still exists/is accessible
      if (await FileAccessService.instance.directoryExists(customPath)) {
        _cachedPdfPath = customPath;
        return customPath;
      } else {
        debugPrint(
          'AppSettingsService: Custom PDF directory no longer exists: $customPath',
        );
        // Fall through to default
      }
    }

    // Return default path
    final appDocDir = await getApplicationDocumentsDirectory();
    _cachedPdfPath = p.join(appDocDir.path, 'feuillet', 'pdfs');
    return _cachedPdfPath!;
  }

  /// Set a custom PDF directory path
  Future<void> setPdfDirectoryPath(String path) async {
    await _database.setAppSetting(AppSettingKeys.pdfDirectoryPath, path);
    _cachedPdfPath = path;

    // On macOS, create a security-scoped bookmark to persist access
    if (!kIsWeb && Platform.isMacOS) {
      await _createBookmark(path);
    }
  }

  /// Clear custom PDF directory path (revert to default)
  Future<void> clearPdfDirectoryPath() async {
    // Stop accessing the old bookmark if any
    if (!kIsWeb && Platform.isMacOS) {
      await _stopAccessingBookmark();
    }
    await _database.deleteAppSetting(AppSettingKeys.pdfDirectoryPath);
    await _database.deleteAppSetting(AppSettingKeys.pdfDirectoryBookmark);
    _cachedPdfPath = null;
    _bookmarkResolved = false;
  }

  /// Check if using a custom PDF directory
  Future<bool> isUsingCustomPdfDirectory() async {
    if (kIsWeb) return false;

    final customPath = await _database.getAppSetting(
      AppSettingKeys.pdfDirectoryPath,
    );
    return customPath != null && customPath.isNotEmpty;
  }

  /// Invalidate cached paths (call after settings change)
  void invalidateCache() {
    _cachedPdfPath = null;
  }

  /// Create and store a security-scoped bookmark for the given directory.
  Future<void> _createBookmark(String path) async {
    try {
      final secureBookmarks = SecureBookmarks();
      final bookmark = await secureBookmarks.bookmark(Directory(path));
      await _database.setAppSetting(
        AppSettingKeys.pdfDirectoryBookmark,
        bookmark,
      );
      _bookmarkResolved = true;
      debugPrint('AppSettingsService: Saved security-scoped bookmark');
    } catch (e) {
      debugPrint('AppSettingsService: Failed to create bookmark: $e');
    }
  }

  /// Resolve a stored security-scoped bookmark to regain directory access.
  Future<void> _resolveBookmark() async {
    try {
      final bookmarkData = await _database.getAppSetting(
        AppSettingKeys.pdfDirectoryBookmark,
      );
      if (bookmarkData == null || bookmarkData.isEmpty) {
        debugPrint('AppSettingsService: No bookmark stored');
        _bookmarkResolved = true;
        return;
      }

      final secureBookmarks = SecureBookmarks();
      final resolved = await secureBookmarks.resolveBookmark(
        bookmarkData,
        isDirectory: true,
      );
      await secureBookmarks.startAccessingSecurityScopedResource(resolved);
      _bookmarkResolved = true;
      debugPrint(
        'AppSettingsService: Resolved bookmark, access restored to ${resolved.path}',
      );
    } catch (e) {
      debugPrint('AppSettingsService: Failed to resolve bookmark: $e');
      _bookmarkResolved = true; // Don't retry on every call
    }
  }

  /// Stop accessing the security-scoped resource.
  Future<void> _stopAccessingBookmark() async {
    try {
      final customPath = await _database.getAppSetting(
        AppSettingKeys.pdfDirectoryPath,
      );
      if (customPath != null && customPath.isNotEmpty) {
        final secureBookmarks = SecureBookmarks();
        await secureBookmarks.stopAccessingSecurityScopedResource(
          Directory(customPath),
        );
      }
    } catch (e) {
      debugPrint('AppSettingsService: Failed to stop accessing bookmark: $e');
    }
  }
}
