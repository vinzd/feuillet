import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';

/// Helper class for layer-related dialogs
class LayerDialogs {
  /// Show a text input dialog
  static Future<String?> showTextInputDialog({
    required BuildContext context,
    required String title,
    required String labelText,
    String? initialValue,
    String? confirmText,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmText ?? context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  /// Show a confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDangerous
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText ?? context.l10n.confirm),
          ),
        ],
      ),
    );
  }
}
