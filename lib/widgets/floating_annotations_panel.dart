import 'package:flutter/material.dart';
import '../models/database.dart';
import '../services/annotation_service.dart';
import 'layer_dialogs.dart';

/// A compact floating panel for annotation tools and layer selection
class FloatingAnnotationsPanel extends StatefulWidget {
  final int documentId;
  final int? selectedLayerId;
  final Function(int) onLayerSelected;
  final VoidCallback onLayersChanged;
  final VoidCallback onClose;
  final Function(Offset delta)? onDrag;

  // Annotation tools
  final bool isAnnotationMode;
  final VoidCallback onAnnotationModeToggle;
  final AnnotationType currentTool;
  final Color annotationColor;
  final double annotationThickness;
  final ValueChanged<AnnotationType> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onThicknessChanged;

  const FloatingAnnotationsPanel({
    super.key,
    required this.documentId,
    this.selectedLayerId,
    required this.onLayerSelected,
    required this.onLayersChanged,
    required this.onClose,
    this.onDrag,
    required this.isAnnotationMode,
    required this.onAnnotationModeToggle,
    required this.currentTool,
    required this.annotationColor,
    required this.annotationThickness,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onThicknessChanged,
  });

  @override
  State<FloatingAnnotationsPanel> createState() =>
      _FloatingAnnotationsPanelState();
}

/// Available annotation colors
const _annotationColors = [
  Colors.red,
  Colors.blue,
  Colors.green,
  Colors.yellow,
  Colors.black,
];

class _FloatingAnnotationsPanelState extends State<FloatingAnnotationsPanel> {
  final _annotationService = AnnotationService();
  List<AnnotationLayer> _layers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayers();
  }

  @override
  void didUpdateWidget(FloatingAnnotationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _loadLayers();
    }
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
    final name = 'Layer ${_layers.length + 1}';
    final layerId = await _annotationService.createLayer(
      widget.documentId,
      name,
    );
    await _loadLayers();
    widget.onLayerSelected(layerId);
    widget.onLayersChanged();
  }

  Future<void> _toggleVisibility(AnnotationLayer layer) async {
    // Don't allow hiding the selected layer when in annotation mode
    if (widget.isAnnotationMode &&
        layer.id == widget.selectedLayerId &&
        layer.isVisible) {
      return;
    }
    await _annotationService.toggleLayerVisibility(layer);
    await _loadLayers();
    widget.onLayersChanged();
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

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Container(
        width: 220,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header (draggable)
            _buildHeader(),
            const Divider(height: 1),

            // Tools section (when in annotation mode)
            if (widget.isAnnotationMode) ...[
              _buildToolsSection(),
              const Divider(height: 1),
            ],

            // Layers section
            _buildLayersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GestureDetector(
      onPanUpdate: widget.onDrag != null
          ? (details) => widget.onDrag!(details.delta)
          : null,
      child: MouseRegion(
        cursor: widget.onDrag != null
            ? SystemMouseCursors.grab
            : SystemMouseCursors.basic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, size: 18),
              const SizedBox(width: 4),
              const Text(
                'Annotations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: Switch(
                  value: widget.isAnnotationMode,
                  onChanged: (_) => widget.onAnnotationModeToggle(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool selection row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolButton(
                icon: Icons.edit,
                tooltip: 'Pen',
                isSelected: widget.currentTool == AnnotationType.pen,
                onPressed: () => widget.onToolChanged(AnnotationType.pen),
              ),
              _ToolButton(
                icon: Icons.highlight,
                tooltip: 'Highlighter',
                isSelected: widget.currentTool == AnnotationType.highlighter,
                onPressed: () =>
                    widget.onToolChanged(AnnotationType.highlighter),
              ),
              _ToolButton(
                icon: Icons.auto_fix_high,
                tooltip: 'Eraser',
                isSelected: widget.currentTool == AnnotationType.eraser,
                onPressed: () => widget.onToolChanged(AnnotationType.eraser),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Color picker row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final color in _annotationColors)
                _ColorButton(
                  color: color,
                  isSelected: widget.annotationColor == color,
                  onTap: () => widget.onColorChanged(color),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Thickness slider
          Row(
            children: [
              const Icon(Icons.line_weight, size: 16),
              Expanded(
                child: Slider(
                  value: widget.annotationThickness,
                  min: 1,
                  max: 12,
                  divisions: 11,
                  onChanged: widget.onThicknessChanged,
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(
                  '${widget.annotationThickness.round()}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayersSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layers header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.layers, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Layers',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: _createNewLayer,
                  tooltip: 'New layer',
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),

        // Layers list
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_layers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('No layers', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _createNewLayer,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create'),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _layers.length,
              itemBuilder: (context, index) {
                final layer = _layers[index];
                final isSelected = layer.id == widget.selectedLayerId;
                final canToggleVisibility =
                    !(widget.isAnnotationMode && isSelected && layer.isVisible);

                return InkWell(
                  onTap: () async {
                    // Auto-show hidden layer when selecting in annotation mode
                    if (widget.isAnnotationMode && !layer.isVisible) {
                      await _annotationService.toggleLayerVisibility(layer);
                      await _loadLayers();
                      widget.onLayersChanged();
                    }
                    widget.onLayerSelected(layer.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15)
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: IconButton(
                            icon: Icon(
                              layer.isVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16,
                              color: canToggleVisibility
                                  ? null
                                  : Theme.of(context).disabledColor,
                            ),
                            onPressed: canToggleVisibility
                                ? () => _toggleVisibility(layer)
                                : null,
                            padding: EdgeInsets.zero,
                            tooltip: canToggleVisibility
                                ? (layer.isVisible
                                      ? 'Hide layer'
                                      : 'Show layer')
                                : 'Cannot hide active layer',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            layer.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16),
                            padding: EdgeInsets.zero,
                            onSelected: (value) => switch (value) {
                              'rename' => _renameLayer(layer),
                              'delete' => _deleteLayer(layer),
                              _ => null,
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Rename'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Tool button widget
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: isSelected ? Theme.of(context).colorScheme.primary : null,
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
            : null,
      ),
    );
  }
}

/// Color button widget
class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade400,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
