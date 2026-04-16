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
  String? _currentPath;
  bool _isCustomPath = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);

    _currentPath = await AppSettingsService.instance.getPdfDirectoryPath();
    _isCustomPath = await AppSettingsService.instance
        .isUsingCustomPdfDirectory();

    setState(() => _isLoading = false);
  }

  Future<void> _selectDirectory() async {
    final result = await FileAccessService.instance.pickDirectory();
    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      await AppSettingsService.instance.setPdfDirectoryPath(result);
      await FileWatcherService.instance.updatePdfDirectoryPath();
      await DocumentService.instance.scanAndSyncLibrary();
      // Reconcile set lists from the new directory's setlists/ folder.
      final pdfDir = await AppSettingsService.instance.getPdfDirectoryPath();
      await SyncManager.instance.reconcileOnStartup(
        db: DatabaseService.instance.database,
        pdfDirectoryPath: pdfDir,
      );
      await _loadCurrentSettings();

      if (mounted) {
        context.showSnackbar(context.l10n.pdfDirectoryUpdated(result));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showSnackbar(context.l10n.errorUpdatingDirectory(e.toString()));
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await LayerDialogs.showConfirmationDialog(
      context: context,
      title: context.l10n.resetToDefaultTitle,
      message: context.l10n.resetToDefaultMessage,
      confirmText: context.l10n.reset,
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await AppSettingsService.instance.clearPdfDirectoryPath();
      await FileWatcherService.instance.updatePdfDirectoryPath();
      await DocumentService.instance.scanAndSyncLibrary();
      await _loadCurrentSettings();

      if (mounted) {
        context.showSnackbar(context.l10n.resetToDefaultPdfDirectory);
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

  @override
  Widget build(BuildContext context) {
    final versionInfo = ref.watch(versionInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // PDF Directory Section
                _buildSectionHeader(context.l10n.librarySection),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(context.l10n.pdfDirectory),
                  subtitle: Text(
                    _currentPath ?? context.l10n.loading,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCustomPath && !kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.restore),
                          tooltip: context.l10n.resetToDefault,
                          onPressed: _resetToDefault,
                        ),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: context.l10n.changeDirectory,
                          onPressed: _selectDirectory,
                        ),
                    ],
                  ),
                ),
                if (_isCustomPath)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Chip(
                      label: Text(context.l10n.customDirectory),
                      avatar: const Icon(Icons.check, size: 18),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
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
              ],
            ),
    );
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
