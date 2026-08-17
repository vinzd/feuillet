import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';
import '../models/database.dart';
import '../utils/file_tree.dart';

class FileTreeView extends StatefulWidget {
  final List<Document> documents;
  final ValueChanged<Document> onDocumentTap;
  final bool isSelectionMode;
  final Set<int> selectedDocumentIds;
  final ValueChanged<Document>? onDocumentCheckboxTap;
  final ValueChanged<Document>? onDocumentLongPress;

  const FileTreeView({
    super.key,
    required this.documents,
    required this.onDocumentTap,
    this.isSelectionMode = false,
    this.selectedDocumentIds = const {},
    this.onDocumentCheckboxTap,
    this.onDocumentLongPress,
  });

  @override
  State<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends State<FileTreeView> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final nodes = buildFileTree(widget.documents);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: nodes
              .expand((node) => _buildNode(context, node, 0, isCompact))
              .toList(),
        );
      },
    );
  }

  List<Widget> _buildNode(
    BuildContext context,
    FileTreeNode node,
    int depth,
    bool isCompact,
  ) {
    if (node.isFolder) {
      final isExpanded = _expandedFolders.contains(node.path);
      final childCount = _countDocuments(node);
      if (isCompact) {
        return [_buildCompactGroup(context, node, isExpanded, childCount)];
      }
      return [
        _buildFolderRow(context, node, depth, isExpanded, childCount, false),
        if (isExpanded)
          ...node.children.expand(
            (child) => _buildNode(context, child, depth + 1, false),
          ),
      ];
    }
    return [_buildDocumentRow(context, node, depth, isCompact)];
  }

  Widget _buildCompactGroup(
    BuildContext context,
    FileTreeNode node,
    bool isExpanded,
    int childCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('compact-group-${node.path}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(70),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        children: [
          _buildFolderRow(context, node, 0, isExpanded, childCount, true),
          if (isExpanded)
            ...node.children.expand(
              (child) => _buildNode(context, child, 0, true),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderRow(
    BuildContext context,
    FileTreeNode node,
    int depth,
    bool isExpanded,
    int childCount,
    bool isCompact,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('folder-toggle-${node.path}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        if (isExpanded) {
          _expandedFolders.remove(node.path);
        } else {
          _expandedFolders.add(node.path);
        }
      }),
      child: Padding(
        padding: EdgeInsets.only(left: isCompact ? 12 : depth * 24.0, right: 8),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              _buildBranchIcon(isExpanded, colorScheme.primary),
              const SizedBox(width: 8),
              Icon(
                isExpanded ? Icons.folder_open : Icons.folder_outlined,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  node.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                isCompact
                    ? '$childCount'
                    : '$childCount ${context.l10n.treeItems}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentRow(
    BuildContext context,
    FileTreeNode node,
    int depth,
    bool isCompact,
  ) {
    final document = node.document!;
    final isSelected = widget.selectedDocumentIds.contains(document.id);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: isCompact ? 12 : depth * 24.0,
        right: 8,
        bottom: 2,
      ),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withAlpha(150)
            : colorScheme.surface.withAlpha(150),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('tree-document-${document.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => widget.onDocumentTap(document),
          onLongPress: widget.onDocumentLongPress == null
              ? null
              : () => widget.onDocumentLongPress!(document),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  document.isImage
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    document.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (widget.isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) =>
                        widget.onDocumentCheckboxTap?.call(document),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchIcon(bool isExpanded, Color color) {
    return SizedBox(
      width: 18,
      child: Icon(
        isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
        size: 18,
        color: color,
      ),
    );
  }

  int _countDocuments(FileTreeNode node) {
    if (!node.isFolder) return 1;
    return node.children.fold(
      0,
      (count, child) => count + _countDocuments(child),
    );
  }
}
