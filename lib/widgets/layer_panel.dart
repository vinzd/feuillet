import 'package:flutter/material.dart';
import '../models/database.dart';
import '../services/annotation_service.dart';
import 'layer_dialogs.dart';

/// Panel for managing annotation layers
class LayerPanel extends StatefulWidget {
  final int documentId;
  final int? selectedLayerId;
  final Function(int) onLayerSelected;
  final VoidCallback onLayersChanged;

  const LayerPanel({
    super.key,
    required this.documentId,
    this.selectedLayerId,
    required this.onLayerSelected,
    required this.onLayersChanged,
  });

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  final _annotationService = AnnotationService();
  List<AnnotationLayer> _layers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  Future<void> _loadLayers() async {
    setState(() => _isLoading = true);
    final layers = await _annotationService.getLayers(widget.documentId);
    setState(() {
      _layers = layers;
      _isLoading = false;
    });
  }

  Future<void> _createNewLayer() async {
    final name = await LayerDialogs.showTextInputDialog(
      context: context,
      title: 'New Layer',
      labelText: 'Layer name',
      initialValue: 'Layer ${_layers.length + 1}',
    );

    if (name != null && name.isNotEmpty) {
      final layerId =
          await _annotationService.createLayer(widget.documentId, name);
      await _loadLayers();
      widget.onLayerSelected(layerId);
      widget.onLayersChanged();
    }
  }

  Future<void> _deleteLayer(AnnotationLayer layer) async {
    final confirmed = await LayerDialogs.showConfirmationDialog(
      context: context,
      title: 'Delete Layer',
      message:
          'Are you sure you want to delete "${layer.name}"? This will delete all annotations on this layer.',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (confirmed == true) {
      await _annotationService.deleteLayer(layer.id);
      await _loadLayers();
      widget.onLayersChanged();
    }
  }

  Future<void> _renameLayer(AnnotationLayer layer) async {
    final newName = await LayerDialogs.showTextInputDialog(
      context: context,
      title: 'Rename Layer',
      labelText: 'Layer name',
      initialValue: layer.name,
    );

    if (newName != null && newName.isNotEmpty && newName != layer.name) {
      await _annotationService.renameLayer(layer, newName);
      await _loadLayers();
      widget.onLayersChanged();
    }
  }

  Future<void> _toggleVisibility(AnnotationLayer layer) async {
    await _annotationService.toggleLayerVisibility(layer);
    await _loadLayers();
    widget.onLayersChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Layers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _createNewLayer,
                  tooltip: 'New layer',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Layers list
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_layers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 48,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('No layers yet'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _createNewLayer,
                    icon: const Icon(Icons.add),
                    label: const Text('Create layer'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _layers.length,
                itemBuilder: (context, index) {
                  final layer = _layers[index];
                  final isSelected = layer.id == widget.selectedLayerId;

                  return ListTile(
                    selected: isSelected,
                    leading: IconButton(
                      icon: Icon(
                        layer.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => _toggleVisibility(layer),
                      tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                    ),
                    title: Text(layer.name),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            _renameLayer(layer);
                            break;
                          case 'delete':
                            _deleteLayer(layer);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      widget.onLayerSelected(layer.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
