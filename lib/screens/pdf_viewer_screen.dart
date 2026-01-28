import 'dart:async';
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
import '../utils/page_spread_calculator.dart';
import '../widgets/cached_pdf_view.dart';
import '../widgets/cached_pdf_page.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/layer_panel.dart';
import '../widgets/annotation_toolbar.dart';
import '../widgets/display_settings_panel.dart';
import '../widgets/pdf_bottom_controls.dart';
import '../widgets/two_page_pdf_view.dart';

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

  bool _isLoading = true;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // View settings
  double _zoomLevel = 1.0;
  double _brightness = 0.0;
  double _contrast = 1.0;
  int _currentPage = 1;
  PdfViewMode _viewMode = PdfViewMode.single;
  PdfDocument? _pdfDocument;

  // Annotation settings
  bool _annotationMode = false;
  final _annotationService = AnnotationService();
  List<AnnotationLayer> _layers = [];
  int? _selectedLayerId;
  AnnotationType _currentTool = AnnotationType.pen;
  Color _annotationColor = Colors.red;
  double _annotationThickness = 3.0;
  Map<int, List<DrawingStroke>> _pageAnnotations = {};
  Map<int, List<DrawingStroke>> _rightPageAnnotations = {};

  /// Flatten annotations from all layers into a single list
  List<DrawingStroke> _flattenAnnotations(
    Map<int, List<DrawingStroke>> annotations,
  ) {
    return annotations.values.expand((strokes) => strokes).toList();
  }

  @override
  void initState() {
    super.initState();
    _initializePdf();
  }

  Future<void> _initializePdf() async {
    try {
      final db = ref.read(databaseProvider);

      // Load settings first (fast operation)
      _settings = await db.getDocumentSettings(widget.document.id);
      if (_settings != null) {
        _zoomLevel = _settings!.zoomLevel;
        _brightness = _settings!.brightness;
        _contrast = _settings!.contrast;
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
    } else {
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
        zoomLevel: drift.Value(_zoomLevel),
        brightness: drift.Value(_brightness),
        contrast: drift.Value(_contrast),
        currentPage: drift.Value(_currentPage - 1), // Convert to 0-based
        viewMode: drift.Value(_viewMode.toStorageString()),
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
          onTap: _toggleControls,
          child: Stack(
            children: [
              // PDF viewer - single or two-page mode
              // Annotations are handled internally for both modes
              Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_createColorMatrix()),
                  child: Transform.scale(
                    scale: _zoomLevel,
                    child: _viewMode == PdfViewMode.single
                        ? _buildSinglePageView()
                        : _buildTwoPageView(),
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
                        _annotationMode ? Icons.edit : Icons.edit_outlined,
                      ),
                      onPressed: () {
                        setState(() => _annotationMode = !_annotationMode);
                      },
                      tooltip: 'Annotations',
                    ),
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
                child: Builder(
                  builder: (context) {
                    final spread = _getCurrentSpread();
                    return PdfBottomControls(
                      currentPage: spread.leftPage,
                      rightPage: spread.rightPage,
                      totalPages: widget.document.pageCount,
                      viewMode: _viewMode,
                      zoomLevel: _zoomLevel,
                      onPreviousPage: _canGoToPrevious()
                          ? _goToPreviousPage
                          : null,
                      onNextPage: _canGoToNext() ? _goToNextPage : null,
                      onZoomChanged: (value) =>
                          setState(() => _zoomLevel = value),
                      onZoomChangeEnd: (value) => _saveSettings(),
                      onInteraction: _resetControlsTimer,
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
            existingStrokes: _flattenAnnotations(_pageAnnotations),
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
      leftPageAnnotations: _flattenAnnotations(_pageAnnotations),
      rightPageAnnotations: _flattenAnnotations(_rightPageAnnotations),
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
