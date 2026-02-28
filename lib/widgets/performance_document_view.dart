import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../utils/viewer_constants.dart';
import '../models/database.dart';
import '../models/view_mode.dart';
import '../services/annotation_service.dart';
import '../services/pdf_page_cache_service.dart';
import '../utils/page_spread_calculator.dart';
import 'cached_pdf_page.dart';
import 'drawing_canvas.dart';
import 'two_page_pdf_view.dart';

/// A widget for displaying a single document in performance mode.
///
/// Supports multiple view modes (single, booklet, continuous double),
/// displays annotations read-only, and pre-renders pages for smooth navigation.
class PerformanceDocumentView extends StatefulWidget {
  const PerformanceDocumentView({
    required this.document,
    required this.pdfDocument,
    required this.viewMode,
    this.initialPage = 1,
    this.onReachedStart,
    this.onReachedEnd,
    this.onPageChanged,
    super.key,
  });

  /// The document metadata
  final Document document;

  /// The loaded PDF document
  final PdfDocument pdfDocument;

  /// The view mode (single, booklet, or continuous double)
  final PdfViewMode viewMode;

  /// Initial page to display (1-indexed)
  final int initialPage;

  /// Called when at first page/spread and user tries to go previous
  final VoidCallback? onReachedStart;

  /// Called when at last page/spread and user tries to go next
  final VoidCallback? onReachedEnd;

  /// Called when the current page changes, with left page and optional right page
  final ValueChanged<({int left, int? right})>? onPageChanged;

  @override
  State<PerformanceDocumentView> createState() =>
      PerformanceDocumentViewState();
}

class PerformanceDocumentViewState extends State<PerformanceDocumentView> {
  final _annotationService = AnnotationService();

  int _currentPage = 1;
  PageController? _pageController;

  Map<int, List<DrawingStroke>> _leftPageAnnotations = {};
  Map<int, List<DrawingStroke>> _rightPageAnnotations = {};
  List<AnnotationLayer> _layers = [];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, widget.document.pageCount);
    _initializePageController();
    _loadLayers();
  }

  @override
  void didUpdateWidget(PerformanceDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If document changed, reset everything
    if (oldWidget.document.id != widget.document.id) {
      _currentPage = widget.initialPage.clamp(1, widget.document.pageCount);
      _initializePageController();
      _loadLayers();
      return;
    }

    // If view mode changed, we may need to adjust the current spread
    if (oldWidget.viewMode != widget.viewMode) {
      _initializePageController();
      _loadPageAnnotations();
      _preRenderPages();
    }
  }

  void _initializePageController() {
    _pageController?.dispose();

    if (widget.viewMode == PdfViewMode.single) {
      _pageController = PageController(initialPage: _currentPage - 1);
    } else {
      final spreadIndex = PageSpreadCalculator.getSpreadForPage(
        widget.viewMode,
        _currentPage,
        widget.document.pageCount,
      );
      _pageController = PageController(initialPage: spreadIndex);
    }
  }

  Future<void> _loadLayers() async {
    _layers = await _annotationService.getLayers(widget.document.id);
    await _loadPageAnnotations();
    _preRenderPages();
  }

  Future<void> _loadPageAnnotations() async {
    final spread = _getCurrentSpread();

    final leftAnnotations = await _annotationService.getAllPageAnnotations(
      widget.document.id,
      spread.leftPage - 1,
    );

    final rightAnnotations = spread.rightPage != null
        ? await _annotationService.getAllPageAnnotations(
            widget.document.id,
            spread.rightPage! - 1,
          )
        : <int, List<DrawingStroke>>{};

    if (mounted) {
      setState(() {
        _leftPageAnnotations = leftAnnotations;
        _rightPageAnnotations = rightAnnotations;
      });
    }
  }

  void _preRenderPages() {
    final spread = _getCurrentSpread();
    PdfPageCacheService.instance.preRenderPages(
      document: widget.pdfDocument,
      currentPage: spread.leftPage,
      totalPages: widget.document.pageCount,
    );
  }

  ({int leftPage, int? rightPage}) _getCurrentSpread() {
    return PageSpreadCalculator.getPagesForSpread(
      widget.viewMode,
      PageSpreadCalculator.getSpreadForPage(
        widget.viewMode,
        _currentPage,
        widget.document.pageCount,
      ),
      widget.document.pageCount,
    );
  }

  bool _canGoToPrevious() {
    if (widget.viewMode == PdfViewMode.single) {
      return _currentPage > 1;
    }
    final currentSpread = PageSpreadCalculator.getSpreadForPage(
      widget.viewMode,
      _currentPage,
      widget.document.pageCount,
    );
    return currentSpread > 0;
  }

  bool _canGoToNext() {
    if (widget.viewMode == PdfViewMode.single) {
      return _currentPage < widget.document.pageCount;
    }
    final currentSpread = PageSpreadCalculator.getSpreadForPage(
      widget.viewMode,
      _currentPage,
      widget.document.pageCount,
    );
    final totalSpreads = PageSpreadCalculator.getTotalSpreads(
      widget.viewMode,
      widget.document.pageCount,
    );
    return currentSpread < totalSpreads - 1;
  }

  bool goToPrevious() {
    if (!_canGoToPrevious()) {
      widget.onReachedStart?.call();
      return false;
    }

    if (widget.viewMode == PdfViewMode.single) {
      _pageController?.previousPage(
        duration: ViewerConstants.pageAnimationDuration,
        curve: ViewerConstants.pageAnimationCurve,
      );
    } else {
      final currentSpread = PageSpreadCalculator.getSpreadForPage(
        widget.viewMode,
        _currentPage,
        widget.document.pageCount,
      );
      final prevSpread = PageSpreadCalculator.getPagesForSpread(
        widget.viewMode,
        currentSpread - 1,
        widget.document.pageCount,
      );
      _updateCurrentPage(prevSpread.leftPage, prevSpread.rightPage);
    }
    return true;
  }

  bool goToNext() {
    if (!_canGoToNext()) {
      widget.onReachedEnd?.call();
      return false;
    }

    if (widget.viewMode == PdfViewMode.single) {
      _pageController?.nextPage(
        duration: ViewerConstants.pageAnimationDuration,
        curve: ViewerConstants.pageAnimationCurve,
      );
    } else {
      final currentSpread = PageSpreadCalculator.getSpreadForPage(
        widget.viewMode,
        _currentPage,
        widget.document.pageCount,
      );
      final nextSpread = PageSpreadCalculator.getPagesForSpread(
        widget.viewMode,
        currentSpread + 1,
        widget.document.pageCount,
      );
      _updateCurrentPage(nextSpread.leftPage, nextSpread.rightPage);
    }
    return true;
  }

  void goToFirst() {
    if (widget.viewMode == PdfViewMode.single) {
      _pageController?.jumpToPage(0);
    } else {
      _updateCurrentPage(1, widget.document.pageCount > 1 ? 2 : null);
    }
  }

  void goToLast() {
    final totalPages = widget.document.pageCount;
    if (widget.viewMode == PdfViewMode.single) {
      _pageController?.jumpToPage(totalPages - 1);
    } else {
      final lastSpread = PageSpreadCalculator.getPagesForSpread(
        widget.viewMode,
        PageSpreadCalculator.getTotalSpreads(widget.viewMode, totalPages) - 1,
        totalPages,
      );
      _updateCurrentPage(lastSpread.leftPage, lastSpread.rightPage);
    }
  }

  void _updateCurrentPage(int leftPage, int? rightPage) {
    setState(() {
      _currentPage = leftPage;
    });
    widget.onPageChanged?.call((left: leftPage, right: rightPage));
    _loadPageAnnotations();
    _preRenderPages();
  }

  void _onSinglePageChanged(int index) {
    final page = index + 1;
    setState(() {
      _currentPage = page;
    });
    widget.onPageChanged?.call((left: page, right: null));
    _loadPageAnnotations();
    _preRenderPages();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.viewMode == PdfViewMode.single
        ? _buildSinglePageView()
        : _buildTwoPageView();
  }

  Widget _buildSinglePageView() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      pageSnapping: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.document.pageCount,
      onPageChanged: _onSinglePageChanged,
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        final isCurrentPage = pageNumber == _currentPage;

        // Build annotation overlay (read-only)
        Widget? annotationOverlay;
        if (isCurrentPage && _layers.isNotEmpty) {
          annotationOverlay = DrawingCanvas(
            key: ValueKey('perf-${widget.document.id}-$pageNumber'),
            layerId: _layers.first.id,
            pageNumber: pageNumber - 1,
            toolType: AnnotationType.pen,
            color: Colors.red,
            thickness: 3.0,
            layerAnnotations: _leftPageAnnotations,
            isEnabled: false, // Read-only in performance mode
          );
        }

        return CachedPdfPage(
          document: widget.pdfDocument,
          pageNumber: pageNumber,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          annotationOverlay: annotationOverlay,
        );
      },
    );
  }

  Widget _buildTwoPageView() {
    final spread = _getCurrentSpread();

    return TwoPagePdfView(
      document: widget.pdfDocument,
      leftPageNumber: spread.leftPage,
      rightPageNumber: spread.rightPage,
      leftPageAnnotations: _leftPageAnnotations,
      rightPageAnnotations: _rightPageAnnotations,
      isAnnotationMode: false, // Read-only
      selectedLayerId: _layers.isNotEmpty ? _layers.first.id : null,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
    );
  }
}
