import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../models/database.dart';
import '../services/annotation_service.dart';
import '../services/pdf_export_service.dart';

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
  final _exportService = PdfExportService.instance;

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
        _error = 'Failed to load layers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _export() async {
    if (_selectedLayerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one layer')),
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
          ).showSnackBar(const SnackBar(content: Text('PDF downloaded')));
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
          _error = 'Export failed: $e';
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export PDF'),
      content: SizedBox(width: 300, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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
              : const Text('Export'),
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
          _error!,
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
            Text('Exporting page $_exportProgress of $_exportTotal...'),
          ],
        ),
      );
    }

    if (_layers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No annotation layers found.'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select layers to include:',
          style: TextStyle(fontWeight: FontWeight.w500),
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
                        'Hidden',
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
          '${_selectedLayerIds.length} layer(s) selected',
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
