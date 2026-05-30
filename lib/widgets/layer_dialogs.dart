import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../models/database.dart';

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

  /// Show a dialog to pick a target layer for merging
  static Future<int?> showMergeDialog({
    required BuildContext context,
    required AnnotationLayer sourceLayer,
    required List<AnnotationLayer> otherLayers,
  }) {
    int? selectedId = otherLayers.first.id;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.mergeLayerTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.mergeLayerMessage(sourceLayer.name)),
              const SizedBox(height: 16),
              RadioGroup<int>(
                groupValue: selectedId!,
                onChanged: (value) => setState(() => selectedId = value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final layer in otherLayers)
                      RadioListTile<int>(
                        title: Text(layer.name),
                        value: layer.id,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedId),
              child: Text(context.l10n.merge),
            ),
          ],
        ),
      ),
    );
  }

  static const _recolorOptions = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.black,
    Colors.orange,
    Colors.purple,
    Colors.brown,
  ];

  /// Show a dialog to pick a color for recoloring all strokes
  static Future<Color?> showRecolorDialog({
    required BuildContext context,
    required String layerName,
  }) {
    Color? selected = _recolorOptions.first;

    return showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.l10n.recolorLayerTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.recolorLayerMessage(layerName)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _recolorOptions)
                    GestureDetector(
                      onTap: () => setState(() => selected = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected == color
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade400,
                            width: selected == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(context.l10n.apply),
            ),
          ],
        ),
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
