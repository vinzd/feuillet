import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../models/database.dart';
import '../providers/label_providers.dart';
import '../services/label_service.dart';

class LabelManagementScreen extends ConsumerWidget {
  const LabelManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(allLabelsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.manageLabels)),
      body: labelsAsync.when(
        data: (labels) {
          if (labels.isEmpty) {
            return Center(child: Text(context.l10n.noLabelsYet));
          }
          return ListView.builder(
            itemCount: labels.length,
            itemBuilder: (context, index) {
              final label = labels[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: label.color != null
                      ? Color(label.color!)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  radius: 16,
                ),
                title: Text(label.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.palette),
                      onPressed: () => _pickColor(context, label),
                      tooltip: context.l10n.changeLabelColor,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _renameLabel(context, label),
                      tooltip: context.l10n.rename,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteLabel(context, label),
                      tooltip: context.l10n.delete,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(context.l10n.errorPrefix(e.toString()))),
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, Label label) async {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.amber,
      Colors.orange,
    ];
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.pickAColor),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Add a "no color" option
            GestureDetector(
              onTap: () => Navigator.pop(context, Colors.transparent),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: const Icon(Icons.close, size: 20),
              ),
            ),
            ...colors.map(
              (c) => GestureDetector(
                onTap: () => Navigator.pop(context, c),
                child: CircleAvatar(backgroundColor: c, radius: 20),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      if (picked == Colors.transparent) {
        await LabelService.instance.updateLabelColor(label.name, null);
      } else {
        await LabelService.instance.updateLabelColor(
          label.name,
          picked.toARGB32(),
        );
      }
    }
  }

  Future<void> _renameLabel(BuildContext context, Label label) async {
    final controller = TextEditingController(text: label.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.renameLabelTitle),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.rename),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.isNotEmpty && newName != label.name) {
      await LabelService.instance.renameLabel(label.name, newName);
    }
  }

  Future<void> _deleteLabel(BuildContext context, Label label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteLabelTitle),
        content: Text(context.l10n.deleteLabelConfirmation(label.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LabelService.instance.deleteLabel(label.name);
    }
  }
}
