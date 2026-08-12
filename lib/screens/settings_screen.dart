import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../services/app_settings_service.dart';
import '../services/file_access_service.dart';
import '../services/file_watcher_service.dart';
import '../services/database_service.dart';
import '../services/document_service.dart';
import '../services/sync_service.dart';
import '../services/log_recorder_service.dart';
import '../services/version_service.dart';
import '../utils/snackbar_extension.dart';
import '../widgets/layer_dialogs.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;
  List<RootDirectory> _roots = const [];
  Timer? _logRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _startLogRefreshIfNeeded();
  }

  @override
  void dispose() {
    _logRefreshTimer?.cancel();
    super.dispose();
  }

  void _startLogRefreshIfNeeded() {
    _logRefreshTimer?.cancel();
    if (LogRecorderService.instance.isRecording) {
      _logRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    _roots = await AppSettingsService.instance.getRootDirectories();
    setState(() => _isLoading = false);
  }

  Future<void> _addRootDirectory() async {
    final result = await FileAccessService.instance.pickDirectory();
    if (result == null) return;

    setState(() => _isLoading = true);
    try {
      await AppSettingsService.instance.addRootDirectory(result);
      await FileWatcherService.instance.updateRootDirectories();
      await DocumentService.instance.scanAndSyncLibrary();
      final rootPaths = await FileWatcherService.instance
          .getPdfDirectoryPaths();
      await SyncManager.instance.reconcileOnStartup(
        db: DatabaseService.instance.database,
        rootPaths: rootPaths,
      );
      await _loadCurrentSettings();

      if (mounted) {
        context.showSnackbar(context.l10n.rootDirectoryAdded(result));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackbar(context.l10n.errorUpdatingDirectory(e.toString()));
      }
    }
  }

  Future<void> _removeRootDirectory(int id, String path) async {
    final confirmed = await LayerDialogs.showConfirmationDialog(
      context: context,
      title: context.l10n.removeRootDirectoryTitle,
      message: context.l10n.removeRootDirectoryConfirm(path),
      confirmText: context.l10n.remove,
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await AppSettingsService.instance.removeRootDirectory(id);
      await FileWatcherService.instance.updateRootDirectories();
      await DocumentService.instance.scanAndSyncLibrary();
      await _loadCurrentSettings();

      if (mounted) {
        context.showSnackbar(context.l10n.rootDirectoryRemoved);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackbar(
          context.l10n.errorResettingDirectory(e.toString()),
        );
      }
    }
  }

  Future<void> _setDefault(int id) async {
    setState(() => _isLoading = true);
    try {
      await AppSettingsService.instance.setDefaultRootDirectory(id);
      await _loadCurrentSettings();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionInfo = ref.watch(versionInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Root directories section
                _buildSectionHeader(context.l10n.librarySection),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    context.l10n.rootDirectoriesSubtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!kIsWeb)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addRootDirectory,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.addDirectory),
                      ),
                    ),
                  ),
                for (final root in _roots) _buildRootTile(root),
                if (_roots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.noRootDirectories,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.customDirectoryNotAvailableOnWeb,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),

                ListTile(
                  leading: const Icon(Icons.label),
                  title: Text(context.l10n.manageLabels),
                  subtitle: Text(context.l10n.manageLabelsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.labelManagement),
                ),

                const Divider(),

                // About Section
                _buildSectionHeader(context.l10n.aboutSection),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(context.l10n.version),
                  subtitle: versionInfo.when(
                    data: (info) => Text(info.displayString),
                    loading: () => Text(context.l10n.loading),
                    error: (error, stack) => Text(context.l10n.unknown),
                  ),
                ),

                const Divider(),

                // Debug Section
                _buildSectionHeader(context.l10n.debugSection),
                _buildLogRecorderTile(),
              ],
            ),
    );
  }

  Widget _buildRootTile(RootDirectory root) {
    final isDefault =
        root.isDefault ||
        (_roots.isNotEmpty &&
            _roots
                    .firstWhere((r) => r.isDefault, orElse: () => _roots.first)
                    .id ==
                root.id);
    return ListTile(
      leading: Icon(isDefault ? Icons.star : Icons.folder),
      title: Row(
        children: [
          Flexible(
            child: Text(
              root.path,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDefault) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text(context.l10n.defaultDirectory),
              avatar: const Icon(Icons.check, size: 18),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDefault && !kIsWeb)
            IconButton(
              icon: const Icon(Icons.star_border),
              tooltip: context.l10n.setAsDefault,
              onPressed: () => _setDefault(root.id),
            ),
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.l10n.removeDirectory,
              onPressed: () => _removeRootDirectory(root.id, root.path),
            ),
        ],
      ),
    );
  }

  Widget _buildLogRecorderTile() {
    final recorder = LogRecorderService.instance;
    final isRecording = recorder.isRecording;

    return ListTile(
      leading: Icon(
        isRecording ? Icons.stop_circle : Icons.bug_report,
        color: isRecording ? Colors.red : null,
      ),
      title: Text(
        isRecording ? context.l10n.stopLogging : context.l10n.startLogging,
      ),
      subtitle: Text(
        isRecording
            ? context.l10n.loggingActive(recorder.entryCount)
            : context.l10n.loggingDescription,
      ),
      trailing: Switch(
        value: isRecording,
        onChanged: (_) => _toggleLogRecording(),
      ),
      onTap: _toggleLogRecording,
    );
  }

  Future<void> _toggleLogRecording() async {
    final recorder = LogRecorderService.instance;
    if (recorder.isRecording) {
      await recorder.stopAndShare();
    } else {
      recorder.start();
    }
    _startLogRefreshIfNeeded();
    setState(() {});
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
