import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:drift/drift.dart' as drift;
import '../models/database.dart';
import '../services/database_service.dart';
import '../services/annotation_service.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/layer_panel.dart';
import '../widgets/annotation_toolbar.dart';
import '../widgets/display_settings_panel.dart';
import '../widgets/pdf_bottom_controls.dart';

/// PDF Viewer screen with zoom, pan, and contrast controls
class PdfViewerScreen extends ConsumerStatefulWidget {
  final Document document;

  const PdfViewerScreen({super.key, required this.document});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  late PdfController _pdfController;
  DocumentSetting? _settings;
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // View settings
  double _zoomLevel = 1.0;
  double _brightness = 0.0;
  double _contrast = 1.0;
  int _currentPage = 1;

  // Annotation settings
  bool _annotationMode = false;
  final _annotationService = AnnotationService();
  List<AnnotationLayer> _layers = [];
  int? _selectedLayerId;
  AnnotationType _currentTool = AnnotationType.pen;
  Color _annotationColor = Colors.red;
  double _annotationThickness = 3.0;
  Map<int, List<DrawingStroke>> _pageAnnotations = {};

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      // Load saved settings
      final db = ref.read(databaseProvider);
      _settings = await db.getDocumentSettings(widget.document.id);

      if (_settings != null) {
        _zoomLevel = _settings!.zoomLevel;
        _brightness = _settings!.brightness;
        _contrast = _settings!.contrast;
        _currentPage = _settings!.currentPage + 1; // Convert to 1-based
      }

      // Initialize PDF controller - use bytes on web, file path on native
      final Future<PdfDocument> pdfDocument;
      if (widget.document.pdfBytes != null) {
        // Web platform: Load from bytes
        pdfDocument = PdfDocument.openData(widget.document.pdfBytes!);
      } else {
        // Native platform: Load from file path
        pdfDocument = PdfDocument.openFile(widget.document.filePath);
      }

      _pdfController = PdfController(
        document: pdfDocument,
        initialPage: _currentPage, // pdfx uses 1-indexed pages
      );

      // Load annotation layers
      await _loadLayers();

      // Load annotations for current page
      await _loadPageAnnotations();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error initializing PDF: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLayers() async {
    _layers = await _annotationService.getLayers(widget.document.id);
    if (_layers.isEmpty) {
      // Create default layer
      final layerId = await _annotationService.createLayer(
        widget.document.id,
        'Layer 1',
      );
      _layers = await _annotationService.getLayers(widget.document.id);
      _selectedLayerId = layerId;
    } else {
      _selectedLayerId = _layers.first.id;
    }
  }

  Future<void> _loadPageAnnotations() async {
    if (_selectedLayerId == null) return;

    final annotations = await _annotationService.getAnnotations(
      _selectedLayerId!,
      _currentPage - 1,
    );

    setState(() {
      _pageAnnotations = {_selectedLayerId!: annotations};
    });
  }

  Future<void> _saveSettings() async {
    final db = ref.read(databaseProvider);
    await db.insertOrUpdateDocumentSettings(
      DocumentSettingsCompanion(
        documentId: drift.Value(widget.document.id),
        zoomLevel: drift.Value(_zoomLevel),
        brightness: drift.Value(_brightness),
        contrast: drift.Value(_contrast),
        currentPage: drift.Value(_currentPage - 1), // Convert to 0-based
      ),
    );
  }

  void _resetControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _resetControlsTimer();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _pdfController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Don't handle keyboard when annotation mode is active
    if (_annotationMode) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Left arrow or Page Up: previous page
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      if (_currentPage > 1) {
        _goToPreviousPage();
        return KeyEventResult.handled;
      }
    }

    // Right arrow, Page Down, or Space: next page
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      if (_currentPage < widget.document.pageCount) {
        _goToNextPage();
        return KeyEventResult.handled;
      }
    }

    // Home: first page
    if (key == LogicalKeyboardKey.home) {
      if (_currentPage != 1) {
        _pdfController.jumpToPage(1); // pdfx uses 1-indexed pages
      }
      return KeyEventResult.handled;
    }

    // End: last page
    if (key == LogicalKeyboardKey.end) {
      final lastPage = widget.document.pageCount;
      if (_currentPage != lastPage) {
        _pdfController.jumpToPage(lastPage); // pdfx uses 1-indexed pages
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _goToPreviousPage() {
    _pdfController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextPage() {
    _pdfController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page; // pdfx provides 1-indexed page numbers
    });
    _saveSettings();
    _loadPageAnnotations();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.document.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // PDF viewer
              Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_createColorMatrix()),
                  child: Transform.scale(
                    scale: _zoomLevel,
                    child: PdfView(
                      controller: _pdfController,
                      scrollDirection: Axis.horizontal,
                      pageSnapping: true,
                      onPageChanged: _onPageChanged,
                      onDocumentError: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error loading PDF: $error')),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Top app bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: AppBar(
                  title: Text(widget.document.name),
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _annotationMode ? Icons.edit : Icons.edit_outlined,
                      ),
                      onPressed: () {
                        setState(() => _annotationMode = !_annotationMode);
                      },
                      tooltip: 'Annotations',
                    ),
                    if (_annotationMode)
                      IconButton(
                        icon: const Icon(Icons.layers),
                        onPressed: _showLayerPanel,
                        tooltip: 'Layers',
                      ),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => _showControlsPanel(),
                      tooltip: 'Display settings',
                    ),
                  ],
                ),
              ),

              // Drawing canvas overlay (when in annotation mode)
              if (_annotationMode && _selectedLayerId != null)
                Positioned.fill(
                  child: DrawingCanvas(
                    key: ValueKey('$_selectedLayerId-$_currentPage'),
                    layerId: _selectedLayerId!,
                    pageNumber: _currentPage - 1,
                    toolType: _currentTool,
                    color: _annotationColor,
                    thickness: _annotationThickness,
                    existingStrokes: _pageAnnotations[_selectedLayerId] ?? [],
                    onStrokeCompleted: _loadPageAnnotations,
                    isEnabled: _annotationMode,
                  ),
                ),

              // Annotation toolbar (when in annotation mode)
              if (_annotationMode)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  top: _showControls ? 80 : -200,
                  left: 0,
                  right: 0,
                  child: AnnotationToolbar(
                    currentTool: _currentTool,
                    annotationColor: _annotationColor,
                    annotationThickness: _annotationThickness,
                    onToolChanged: (tool) =>
                        setState(() => _currentTool = tool),
                    onColorChanged: (color) =>
                        setState(() => _annotationColor = color),
                    onThicknessChanged: (thickness) =>
                        setState(() => _annotationThickness = thickness),
                  ),
                ),

              // Bottom controls
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: PdfBottomControls(
                  currentPage: _currentPage,
                  totalPages: widget.document.pageCount,
                  zoomLevel: _zoomLevel,
                  onPreviousPage: _currentPage > 1 ? _goToPreviousPage : null,
                  onNextPage: _currentPage < widget.document.pageCount
                      ? _goToNextPage
                      : null,
                  onZoomChanged: (value) => setState(() => _zoomLevel = value),
                  onZoomChangeEnd: (value) => _saveSettings(),
                  onInteraction: _resetControlsTimer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showControlsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => DisplaySettingsPanel(
        brightness: _brightness,
        contrast: _contrast,
        onBrightnessChanged: (value) => setState(() => _brightness = value),
        onContrastChanged: (value) => setState(() => _contrast = value),
        onReset: () {
          setState(() {
            _brightness = 0.0;
            _contrast = 1.0;
          });
          _saveSettings();
        },
      ),
    );
  }

  /// Create a color matrix for brightness and contrast adjustment
  List<double> _createColorMatrix() {
    // Brightness and contrast matrix
    final double b = _brightness * 255;
    final double c = _contrast;

    return [
      c, 0, 0, 0, b, // Red
      0, c, 0, 0, b, // Green
      0, 0, c, 0, b, // Blue
      0, 0, 0, 1, 0, // Alpha
    ];
  }

  /// Show layer management panel
  void _showLayerPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LayerPanel(
        documentId: widget.document.id,
        selectedLayerId: _selectedLayerId,
        onLayerSelected: (layerId) {
          setState(() {
            _selectedLayerId = layerId;
          });
          _loadPageAnnotations();
        },
        onLayersChanged: () {
          _loadLayers();
          _loadPageAnnotations();
        },
      ),
    );
  }
}
