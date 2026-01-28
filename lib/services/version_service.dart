import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Git commit hash, passed via --dart-define at build time
const String _gitHash = String.fromEnvironment('GIT_HASH', defaultValue: 'dev');

/// Version information for the app
class VersionInfo {
  final String version;
  final String buildNumber;
  final String gitHash;

  const VersionInfo({
    required this.version,
    required this.buildNumber,
    required this.gitHash,
  });

  /// Returns a short display string like "1.0.0 (abc1234)"
  String get displayString {
    final shortHash = gitHash.length > 7 ? gitHash.substring(0, 7) : gitHash;
    return 'v$version ($shortHash)';
  }
}

/// Service for retrieving app version information
class VersionService {
  VersionService._();

  static final VersionService instance = VersionService._();

  VersionInfo? _cachedInfo;

  /// Get the version info, loading from package info if not cached
  Future<VersionInfo> getVersionInfo() async {
    if (_cachedInfo != null) {
      return _cachedInfo!;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    _cachedInfo = VersionInfo(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      gitHash: _gitHash,
    );

    return _cachedInfo!;
  }
}

/// Provider for version info (async)
final versionInfoProvider = FutureProvider<VersionInfo>((ref) async {
  return VersionService.instance.getVersionInfo();
});
