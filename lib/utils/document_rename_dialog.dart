import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';

/// Shows the rename dialog and returns the trimmed new name, or null if
/// cancelled or unchanged.
Future<String?> showRenameDocumentDialog(
  BuildContext context, {
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  try {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.renameDocumentTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.name),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
            },
            child: Text(context.l10n.rename),
          ),
        ],
      ),
    );

    if (newName == null || newName == currentName) return null;
    return newName;
  } finally {
    controller.dispose();
  }
}
