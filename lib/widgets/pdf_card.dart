import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/database.dart';
import '../services/pdf_service.dart';

/// Card widget to display a PDF in the library grid view
class PdfCard extends StatefulWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxTap;
  final bool isSelectionMode;
  final bool isSelected;

  const PdfCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.onCheckboxTap,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  State<PdfCard> createState() => _PdfCardState();
}

class _PdfCardState extends State<PdfCard> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  bool _hasFailed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(PdfCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasFailed = false;
    });

    try {
      final bytes = await PdfService.instance.generateThumbnail(
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
        child: const Icon(Icons.picture_as_pdf, size: 64),
      );
    }

    return Image.memory(
      _thumbnailBytes!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.picture_as_pdf, size: 64),
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

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.document.name,
            style: textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.document.pageCount} pages',
            style: textTheme.bodySmall?.copyWith(
              color: textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
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
    );
  }
}
