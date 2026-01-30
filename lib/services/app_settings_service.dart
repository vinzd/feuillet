import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';

/// Keys for app settings stored in database
class AppSettingKeys {
  static const pdfDirectoryPath = 'pdf_directory_path';
}

/// Service for managing app-wide settings
class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  final _database = DatabaseService.instance.database;

  /// Cached PDF directory path for performance
  String? _cachedPdfPath;

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
      // Verify the directory still exists
      final dir = Directory(customPath);
      if (await dir.exists()) {
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
  }

  /// Clear custom PDF directory path (revert to default)
  Future<void> clearPdfDirectoryPath() async {
    await _database.deleteAppSetting(AppSettingKeys.pdfDirectoryPath);
    _cachedPdfPath = null;
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
}
