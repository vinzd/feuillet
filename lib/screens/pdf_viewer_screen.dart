import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';
import 'package:drift/drift.dart' as drift;
import '../models/database.dart';
import '../models/view_mode.dart';
import '../services/database_service.dart';
import '../services/annotation_service.dart';
import '../services/pdf_page_cache_service.dart';
import '../utils/auto_hide_controller.dart';
import '../utils/display_settings.dart';
import '../utils/page_spread_calculator.dart';
import '../widgets/cached_pdf_view.dart';
import '../widgets/cached_pdf_page.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/floating_annotations_panel.dart';
import '../widgets/display_settings_panel.dart';
import '../widgets/pdf_bottom_controls.dart';
import '../widgets/two_page_pdf_view.dart';
import '../widgets/export_pdf_dialog.dart';

/// PDF Viewer screen with zoom, pan, and contrast controls
class PdfViewerScreen extends ConsumerStatefulWidget {
  final Document document;

  const PdfViewerScreen({super.key, required this.document});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  CachedPdfController? _pdfController;
  PageController? _singlePageController;
  DocumentSetting? _settings;
  final FocusNode _focusNode = FocusNode();
  late final AutoHideController _autoHideController;

  bool _isLoading = true;

  // View settings
  DisplaySettings _displaySettings = DisplaySettings.defaults;
  int _currentPage = 1;
  PdfViewMode _viewMode = PdfViewMode.single;
  PdfDocument? _pdfDocument;

  // Annotation settings
  bool _annotationMode = false;
  bool _showFloatingLayerPanel = false;
  Offset? _layerPanelPosition;
  final _annotationService = AnnotationService();
  List<AnnotationLayer> _layers = [];
  int? _selectedLayerId;
  AnnotationType _currentTool = AnnotationType.pen;
  Color _annotationColor = Colors.red;
  double _annotationThickness = 3.0;
  Map<int, List<DrawingStroke>> _pageAnnotations = {};
  Map<int, List<DrawingStroke>> _rightPageAnnotations = {};

  @override
  void initState() {
    super.initState();
    _autoHideController = AutoHideController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      final db = ref.read(databaseProvider);

      // Load settings first (fast operation)
      _settings = await db.getDocumentSettings(widget.document.id);
      if (_settings != null) {
        _displaySettings = DisplaySettings(
          zoomLevel: _settings!.zoomLevel,
          brightness: _settings!.brightness,
          contrast: _settings!.contrast,
        );
        _currentPage = _settings!.currentPage + 1; // Convert to 1-based
        _viewMode = PdfViewMode.fromStorageString(_settings!.viewMode);
      }

      // Load layers (fast operation)
      await _loadLayers();

      // Show UI with loading spinner for the PDF area
      setState(() => _isLoading = false);

      // Now load PDF document in background - UI is already visible
      final freshDocument = await db.getDocument(widget.document.id);

      final Future<PdfDocument> pdfDocument;
      if (freshDocument?.pdfBytes != null) {
        // Copy bytes to avoid detached ArrayBuffer issue on web
        final bytesCopy = Uint8List.fromList(freshDocument!.pdfBytes!);
        pdfDocument = PdfDocument.openData(bytesCopy);
      } else if (freshDocument != null) {
        pdfDocument = PdfDocument.openFile(freshDocument.filePath);
      } else {
        throw Exception('Document not found');
      }

      _pdfDocument = await pdfDocument;

      _pdfController = CachedPdfController(
        document: Future.value(_pdfDocument),
        initialPage: _currentPage,
      );

      _singlePageController = PageController(initialPage: _currentPage - 1);

      await _loadPageAnnotations();

      // Trigger rebuild now that PDF is ready
      if (mounted) {
        setState(() {});
      }

      // Trigger pre-rendering of adjacent pages after initial load
      _preRenderPages();
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
    } else if (_selectedLayerId == null ||
        !_layers.any((l) => l.id == _selectedLayerId)) {
      // Only change selection if current selection is invalid
      _selectedLayerId = _layers.first.id;
    }
  }

  Future<void> _loadPageAnnotations() async {
    final spread = _getCurrentSpread();

    // Load annotations from all visible layers for left page
    final leftAnnotations = await _annotationService.getAllPageAnnotations(
      widget.document.id,
      spread.leftPage - 1,
    );

    // Load annotations for right page in two-page mode
    Map<int, List<DrawingStroke>> rightAnnotations = {};
    if (spread.rightPage != null) {
      rightAnnotations = await _annotationService.getAllPageAnnotations(
        widget.document.id,
        spread.rightPage! - 1,
      );
    }

    setState(() {
      _pageAnnotations = leftAnnotations;
      _rightPageAnnotations = rightAnnotations;
    });
  }

  /// Pre-render pages around the current page for faster navigation
  void _preRenderPages() {
    if (_pdfDocument == null) return;

    final spread = _getCurrentSpread();
    // Use leftPage as the basis for pre-rendering
    PdfPageCacheService.instance.preRenderPages(
      document: _pdfDocument!,
      currentPage: spread.leftPage,
      totalPages: widget.document.pageCount,
    );
  }

  Future<void> _saveSettings() async {
    final db = ref.read(databaseProvider);
    await db.insertOrUpdateDocumentSettings(
      DocumentSettingsCompanion(
        documentId: drift.Value(widget.document.id),
        zoomLevel: drift.Value(_displaySettings.zoomLevel),
        brightness: drift.Value(_displaySettings.brightness),
        contrast: drift.Value(_displaySettings.contrast),
        currentPage: drift.Value(_currentPage - 1), // Convert to 0-based
        viewMode: drift.Value(_viewMode.toStorageString()),
      ),
    );
  }

  @override
  void dispose() {
    _autoHideController.dispose();
    _pdfController?.dispose();
    _singlePageController?.dispose();
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

    // Left arrow or Page Up: previous page/spread
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      if (_canGoToPrevious()) {
        _goToPreviousPage();
        return KeyEventResult.handled;
      }
    }

    // Right arrow, Page Down, or Space: next page/spread
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      if (_canGoToNext()) {
        _goToNextPage();
        return KeyEventResult.handled;
      }
    }

    // Home: first page
    if (key == LogicalKeyboardKey.home) {
      if (_currentPage != 1) {
        if (_viewMode == PdfViewMode.single) {
          _singlePageController?.jumpToPage(0); // PageController uses 0-indexed
        } else {
          _pdfController?.jumpToPage(1);
        }
      }
      return KeyEventResult.handled;
    }

    // End: last page
    if (key == LogicalKeyboardKey.end) {
      final lastPage = widget.document.pageCount;
      if (_currentPage != lastPage) {
        if (_viewMode == PdfViewMode.single) {
          _singlePageController?.jumpToPage(
            lastPage - 1,
          ); // PageController uses 0-indexed
        } else {
          _pdfController?.jumpToPage(lastPage);
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _goToPreviousPage() {
    if (_viewMode == PdfViewMode.single) {
      _singlePageController?.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Two-page mode: navigate by spread
      final currentSpread = PageSpreadCalculator.getSpreadForPage(
        _viewMode,
        _currentPage,
        widget.document.pageCount,
      );
      if (currentSpread > 0) {
        final prevSpread = PageSpreadCalculator.getPagesForSpread(
          _viewMode,
          currentSpread - 1,
          widget.document.pageCount,
        );
        setState(() {
          _currentPage = prevSpread.leftPage;
        });
        _saveSettings();
        _loadPageAnnotations();
        _preRenderPages();
      }
    }
  }

  void _goToNextPage() {
    if (_viewMode == PdfViewMode.single) {
      _singlePageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Two-page mode: navigate by spread
      final currentSpread = PageSpreadCalculator.getSpreadForPage(
        _viewMode,
        _currentPage,
        widget.document.pageCount,
      );
      final totalSpreads = PageSpreadCalculator.getTotalSpreads(
        _viewMode,
        widget.document.pageCount,
      );
      if (currentSpread < totalSpreads - 1) {
        final nextSpread = PageSpreadCalculator.getPagesForSpread(
          _viewMode,
          currentSpread + 1,
          widget.document.pageCount,
        );
        setState(() {
          _currentPage = nextSpread.leftPage;
        });
        _saveSettings();
        _loadPageAnnotations();
        _preRenderPages();
      }
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page; // pdfx provides 1-indexed page numbers
    });
    _saveSettings();
    _loadPageAnnotations();
    _preRenderPages();
  }

  void _onViewModeChanged(PdfViewMode mode) {
    setState(() {
      _viewMode = mode;
    });
    _saveSettings();
    _loadPageAnnotations();
    _preRenderPages();
  }

  Future<void> _toggleAnnotationMode() async {
    if (!_annotationMode && _selectedLayerId != null) {
      // Entering annotation mode - ensure active layer is visible
      final activeLayer = _layers.firstWhere(
        (l) => l.id == _selectedLayerId,
        orElse: () => _layers.first,
      );
      if (!activeLayer.isVisible) {
        await _annotationService.toggleLayerVisibility(activeLayer);
        await _loadLayers();
        await _loadPageAnnotations();
      }
    }
    setState(() {
      _annotationMode = !_annotationMode;
      // Show floating layer panel when entering annotation mode
      if (_annotationMode) {
        _showFloatingLayerPanel = true;
      }
    });
  }

  /// Get the current spread info for two-page modes
  ({int leftPage, int? rightPage}) _getCurrentSpread() {
    return PageSpreadCalculator.getPagesForSpread(
      _viewMode,
      PageSpreadCalculator.getSpreadForPage(
        _viewMode,
        _currentPage,
        widget.document.pageCount,
      ),
      widget.document.pageCount,
    );
  }

  /// Check if we can navigate to the previous spread
  bool _canGoToPrevious() {
    if (_viewMode == PdfViewMode.single) {
      return _currentPage > 1;
    }
    final currentSpread = PageSpreadCalculator.getSpreadForPage(
      _viewMode,
      _currentPage,
      widget.document.pageCount,
    );
    return currentSpread > 0;
  }

  /// Check if we can navigate to the next spread
  bool _canGoToNext() {
    if (_viewMode == PdfViewMode.single) {
      return _currentPage < widget.document.pageCount;
    }
    final currentSpread = PageSpreadCalculator.getSpreadForPage(
      _viewMode,
      _currentPage,
      widget.document.pageCount,
    );
    final totalSpreads = PageSpreadCalculator.getTotalSpreads(
      _viewMode,
      widget.document.pageCount,
    );
    return currentSpread < totalSpreads - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.document.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error if PDF controller failed to initialize
    if (_pdfController == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.document.name)),
        body: const Center(
          child: Text('Failed to load PDF. Please try again.'),
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _autoHideController.toggle,
          child: Stack(
            children: [
              // PDF viewer - single or two-page mode
              // Annotations are handled internally for both modes
              Center(
                child: ColorFiltered(
                  colorFilter: _displaySettings.colorFilter,
                  child: Transform.scale(
                    scale: _displaySettings.zoomLevel,
                    child: _viewMode == PdfViewMode.single
                        ? _buildSinglePageView()
                        : _buildTwoPageView(),
                  ),
                ),
              ),

              // Top app bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _autoHideController.isVisible ? 0 : -100,
                left: 0,
                right: 0,
                child: AppBar(
                  title: Text(widget.document.name),
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  actions: [
                    PopupMenuButton<PdfViewMode>(
                      icon: Icon(_viewMode.icon),
                      tooltip: 'View mode',
                      onSelected: _onViewModeChanged,
                      itemBuilder: (context) => PdfViewMode.values
                          .map(
                            (mode) => PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  Icon(
                                    mode.icon,
                                    color: mode == _viewMode
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(mode.displayName),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    IconButton(
                      icon: Icon(
                        _showFloatingLayerPanel
                            ? Icons.brush
                            : Icons.brush_outlined,
                      ),
                      onPressed: () => setState(
                        () =>
                            _showFloatingLayerPanel = !_showFloatingLayerPanel,
                      ),
                      tooltip: 'Annotations',
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => _showControlsPanel(),
                      tooltip: 'Display settings',
                    ),
                    if (_pdfDocument != null)
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => ExportPdfDialog.show(
                          context: context,
                          document: widget.document,
                          pdfDocument: _pdfDocument!,
                        ),
                        tooltip: 'Export PDF',
                      ),
                  ],
                ),
              ),

              // Floating annotations panel (layers + tools)
              if (_showFloatingLayerPanel)
                Positioned(
                  top:
                      _layerPanelPosition?.dy ??
                      (_autoHideController.isVisible ? 80 : 60),
                  right: _layerPanelPosition != null ? null : 16,
                  left: _layerPanelPosition?.dx,
                  child: FloatingAnnotationsPanel(
                    documentId: widget.document.id,
                    selectedLayerId: _selectedLayerId,
                    isAnnotationMode: _annotationMode,
                    onAnnotationModeToggle: _toggleAnnotationMode,
                    currentTool: _currentTool,
                    annotationColor: _annotationColor,
                    annotationThickness: _annotationThickness,
                    onToolChanged: (tool) =>
                        setState(() => _currentTool = tool),
                    onColorChanged: (color) =>
                        setState(() => _annotationColor = color),
                    onThicknessChanged: (thickness) =>
                        setState(() => _annotationThickness = thickness),
                    onLayerSelected: (layerId) {
                      setState(() => _selectedLayerId = layerId);
                      _loadPageAnnotations();
                    },
                    onLayersChanged: () {
                      _loadLayers();
                      _loadPageAnnotations();
                    },
                    onClose: () =>
                        setState(() => _showFloatingLayerPanel = false),
                    onDrag: (delta) => _updateLayerPanelPosition(delta),
                  ),
                ),

              // Bottom controls
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _autoHideController.isVisible ? 0 : -100,
                left: 0,
                right: 0,
                child: Builder(
                  builder: (context) {
                    final spread = _getCurrentSpread();
                    return PdfBottomControls(
                      currentPage: spread.leftPage,
                      rightPage: spread.rightPage,
                      totalPages: widget.document.pageCount,
                      viewMode: _viewMode,
                      zoomLevel: _displaySettings.zoomLevel,
                      onPreviousPage: _canGoToPrevious()
                          ? _goToPreviousPage
                          : null,
                      onNextPage: _canGoToNext() ? _goToNextPage : null,
                      onZoomChanged: (value) => setState(
                        () => _displaySettings = _displaySettings.copyWith(
                          zoomLevel: value,
                        ),
                      ),
                      onZoomChangeEnd: (value) => _saveSettings(),
                      onInteraction: _autoHideController.resetTimer,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePageView() {
    if (_pdfDocument == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Use PageView with CachedPdfPage for consistent rendering
    // Annotations are passed to CachedPdfPage so they scale with the PDF
    return PageView.builder(
      controller: _singlePageController,
      scrollDirection: Axis.horizontal,
      pageSnapping: true,
      itemCount: _pdfDocument!.pagesCount,
      onPageChanged: (index) => _onPageChanged(index + 1),
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final isCurrentPage = pageNumber == _currentPage;

        // Build annotation overlay if on current page with a selected layer
        Widget? annotationOverlay;
        if (isCurrentPage && _selectedLayerId != null) {
          annotationOverlay = DrawingCanvas(
            key: ValueKey('$_selectedLayerId-$pageNumber'),
            layerId: _selectedLayerId!,
            pageNumber: pageNumber - 1,
            toolType: _currentTool,
            color: _annotationColor,
            thickness: _annotationThickness,
            layerAnnotations: _pageAnnotations,
            onStrokeCompleted: _loadPageAnnotations,
            isEnabled: _annotationMode,
          );
        }

        return CachedPdfPage(
          document: _pdfDocument!,
          pageNumber: pageNumber,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          annotationOverlay: annotationOverlay,
        );
      },
    );
  }

  Widget _buildTwoPageView() {
    if (_pdfDocument == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final spread = _getCurrentSpread();

    return TwoPagePdfView(
      document: _pdfDocument!,
      leftPageNumber: spread.leftPage,
      rightPageNumber: spread.rightPage,
      leftPageAnnotations: _pageAnnotations,
      rightPageAnnotations: _rightPageAnnotations,
      isAnnotationMode: _annotationMode,
      selectedLayerId: _selectedLayerId,
      currentTool: _currentTool,
      annotationColor: _annotationColor,
      annotationThickness: _annotationThickness,
      onStrokeCompleted: _loadPageAnnotations,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
    );
  }

  void _showControlsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => DisplaySettingsPanel(
        brightness: _displaySettings.brightness,
        contrast: _displaySettings.contrast,
        onBrightnessChanged: (value) => setState(
          () => _displaySettings = _displaySettings.copyWith(brightness: value),
        ),
        onContrastChanged: (value) => setState(
          () => _displaySettings = _displaySettings.copyWith(contrast: value),
        ),
        onReset: () {
          setState(() {
            _displaySettings = _displaySettings.copyWith(
              brightness: 0.0,
              contrast: 1.0,
            );
          });
          _saveSettings();
        },
      ),
    );
  }

  void _updateLayerPanelPosition(Offset delta) {
    setState(() {
      final size = MediaQuery.of(context).size;
      final defaultPosition = Offset(
        size.width - 236,
        _autoHideController.isVisible ? 80 : 60,
      );
      final currentPos = _layerPanelPosition ?? defaultPosition;
      _layerPanelPosition = Offset(
        (currentPos.dx + delta.dx).clamp(0, size.width - 220),
        (currentPos.dy + delta.dy).clamp(0, size.height - 100),
      );
    });
  }
}
