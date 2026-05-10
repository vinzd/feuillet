import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';
import '../models/database.dart';
import '../services/document_service.dart';
import '../services/label_service.dart';

/// Card widget to display a document in the library grid view
class DocumentCard extends StatefulWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxTap;
  final VoidCallback? onRename;
  final bool isSelectionMode;
  final bool isSelected;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.onCheckboxTap,
    this.onRename,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  bool _hasFailed = false;
  bool _isHovered = false;
  List<Label> _labels = [];
  StreamSubscription<List<Label>>? _labelSubscription;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    _watchLabels();
  }

  @override
  void didUpdateWidget(DocumentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _loadThumbnail();
      _labelSubscription?.cancel();
      _watchLabels();
    }
  }

  @override
  void dispose() {
    _labelSubscription?.cancel();
    super.dispose();
  }

  void _watchLabels() {
    _labelSubscription = LabelService.instance
        .watchLabelsForDocument(widget.document.id)
        .listen((labels) {
          if (mounted) setState(() => _labels = labels);
        });
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });

    try {
      final bytes = await DocumentService.instance.generateThumbnail(
        widget.document,
      );
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
          _hasFailed = bytes == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasFailed = true;
        });
      }
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit, size: 20),
              const SizedBox(width: 8),
              Text(context.l10n.renameDocument),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') widget.onRename?.call();
    });
  }

  Widget _buildThumbnailArea(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasFailed || _thumbnailBytes == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          widget.document.isImage ? Icons.image : Icons.picture_as_pdf,
          size: 64,
        ),
      );
    }

    return Image.memory(
      _thumbnailBytes!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            widget.document.isImage ? Icons.image : Icons.picture_as_pdf,
            size: 64,
          ),
        );
      },
    );
  }

  Widget _buildSelectionCheckbox(ColorScheme colorScheme) {
    return Positioned(
      top: 8,
      left: 8,
      child: GestureDetector(
        onTap: widget.onCheckboxTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.surface.withAlpha(230),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isSelected
                  ? colorScheme.primary
                  : colorScheme.outline,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.check,
            size: 18,
            color: widget.isSelected
                ? colorScheme.onPrimary
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showRenameButton =
        _isHovered && !widget.isSelectionMode && widget.onRename != null;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.document.name,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showRenameButton)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: widget.onRename,
                    tooltip: context.l10n.renameDocument,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                widget.document.isImage
                    ? 'Image'
                    : '${widget.document.pageCount} pages',
                style: textTheme.bodySmall?.copyWith(
                  color: textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
              if (_labels.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    children: _labels
                        .where((l) => l.color != null)
                        .map(
                          (l) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Color(l.color!),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showCheckbox = widget.isSelectionMode || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onRename != null
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: widget.isSelected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.primary, width: 3),
                )
              : null,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildThumbnailArea(context)),
                    _buildInfoSection(context),
                  ],
                ),
                if (showCheckbox) _buildSelectionCheckbox(colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
