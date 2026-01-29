import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_service.dart';
import '../services/file_watcher_service.dart';
import '../services/pdf_service.dart';
import '../services/version_service.dart';

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
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select PDF Directory',
      lockParentWindow: true,
    );

    if (result == null) return; // User cancelled

    // Validate the directory exists and is accessible
    final dir = Directory(result);
    if (!await dir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected directory does not exist')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save the new path
      await AppSettingsService.instance.setPdfDirectoryPath(result);

      // Restart file watcher with new path
      await FileWatcherService.instance.updatePdfDirectoryPath();

      // Rescan library
      await PdfService.instance.scanAndSyncLibrary();

      await _loadCurrentSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF directory updated to: $result')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating directory: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text(
          'This will reset the PDF directory to the default location. '
          'Your existing PDFs will remain in their current location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await AppSettingsService.instance.clearPdfDirectoryPath();
      await FileWatcherService.instance.updatePdfDirectoryPath();
      await PdfService.instance.scanAndSyncLibrary();
      await _loadCurrentSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset to default PDF directory')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting directory: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final versionInfo = ref.watch(versionInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // PDF Directory Section
                _buildSectionHeader('Library'),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('PDF Directory'),
                  subtitle: Text(
                    _currentPath ?? 'Loading...',
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
                          tooltip: 'Reset to default',
                          onPressed: _resetToDefault,
                        ),
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Change directory',
                          onPressed: _selectDirectory,
                        ),
                    ],
                  ),
                ),
                if (_isCustomPath)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Chip(
                      label: const Text('Custom directory'),
                      avatar: const Icon(Icons.check, size: 18),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                    ),
                  ),
                if (kIsWeb)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Custom PDF directory is not available on web.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),

                const Divider(),

                // About Section
                _buildSectionHeader('About'),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: versionInfo.when(
                    data: (info) => Text(info.displayString),
                    loading: () => const Text('Loading...'),
                    error: (error, stack) => const Text('Unknown'),
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
