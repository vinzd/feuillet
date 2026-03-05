import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../l10n/l10n_extension.dart';
import '../models/database.dart';
import '../services/annotation_service.dart';
import '../services/document_export_service.dart';

// Conditional import for web download
import 'export_pdf_dialog_web.dart'
    if (dart.library.io) 'export_pdf_dialog_native.dart'
    as platform;

/// Dialog for exporting PDF with selected annotation layers
class ExportPdfDialog extends StatefulWidget {
  final Document document;
  final PdfDocument pdfDocument;

  const ExportPdfDialog({
    super.key,
    required this.document,
    required this.pdfDocument,
  });

  /// Show the export dialog
  static Future<void> show({
    required BuildContext context,
    required Document document,
    required PdfDocument pdfDocument,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          ExportPdfDialog(document: document, pdfDocument: pdfDocument),
    );
  }

  @override
  State<ExportPdfDialog> createState() => _ExportPdfDialogState();
}

class _ExportPdfDialogState extends State<ExportPdfDialog> {
  final _annotationService = AnnotationService();
  final _exportService = DocumentExportService.instance;

  List<AnnotationLayer> _layers = [];
  Set<int> _selectedLayerIds = {};
  bool _isLoading = true;
  bool _isExporting = false;
  int _exportProgress = 0;
  int _exportTotal = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  Future<void> _loadLayers() async {
    try {
      final layers = await _annotationService.getLayers(widget.document.id);
      setState(() {
        _layers = layers;
        // Pre-select visible layers
        _selectedLayerIds = layers
            .where((l) => l.isVisible)
            .map((l) => l.id)
            .toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _export() async {
    if (_selectedLayerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseSelectAtLeastOneLayer)),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _exportTotal = widget.pdfDocument.pagesCount;
      _error = null;
    });

    try {
      final pdfBytes = await _exportService.exportPdfWithAnnotations(
        document: widget.document,
        pdfDoc: widget.pdfDocument,
        selectedLayerIds: _selectedLayerIds.toList(),
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _exportProgress = current;
              _exportTotal = total;
            });
          }
        },
      );

      if (!mounted) return;

      // Generate filename
      final baseName = widget.document.name.replaceAll('.pdf', '');
      final fileName = '${baseName}_annotated.pdf';

      if (kIsWeb) {
        // Web: trigger browser download
        platform.downloadPdf(pdfBytes, fileName);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.pdfDownloaded)));
        }
      } else {
        // Native: use share sheet
        await _exportService.sharePdf(pdfBytes, fileName);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.exportPdfTitle),
      content: SizedBox(width: 300, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _isExporting || _isLoading || _selectedLayerIds.isEmpty
              ? null
              : _export,
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.export),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.exportFailed(_error!),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_isExporting) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.l10n.exportingPageProgress(_exportProgress, _exportTotal)),
          ],
        ),
      );
    }

    if (_layers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.noAnnotationLayersFound),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.selectLayersToInclude,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 250),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _layers.length,
            itemBuilder: (context, index) {
              final layer = _layers[index];
              final isSelected = _selectedLayerIds.contains(layer.id);

              return CheckboxListTile(
                title: Text(layer.name),
                subtitle: layer.isVisible
                    ? null
                    : Text(
                        context.l10n.hidden,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedLayerIds.add(layer.id);
                    } else {
                      _selectedLayerIds.remove(layer.id);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.layersSelected(_selectedLayerIds.length),
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
