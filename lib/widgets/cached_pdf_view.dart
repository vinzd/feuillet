import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/pdf_page_cache_service.dart';

/// A PDF viewer widget with background page pre-rendering
class CachedPdfView extends StatefulWidget {
  const CachedPdfView({
    required this.controller,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.scrollDirection = Axis.horizontal,
    this.pageSnapping = true,
    this.physics,
    this.backgroundDecoration,
    super.key,
  });

  final CachedPdfController controller;
  final void Function(int page)? onPageChanged;
  final void Function(PdfDocument document)? onDocumentLoaded;
  final void Function(Object error)? onDocumentError;
  final Axis scrollDirection;
  final bool pageSnapping;
  final ScrollPhysics? physics;
  final BoxDecoration? backgroundDecoration;

  @override
  State<CachedPdfView> createState() => _CachedPdfViewState();
}

class _CachedPdfViewState extends State<CachedPdfView> {
  PdfDocument? _document;
  bool _isLoading = true;
  Object? _error;
  bool _initialPreRenderDone = false;

  final _cacheService = PdfPageCacheService.instance;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      _document = await widget.controller.document;
      widget.controller._attach(_document!);
      widget.onDocumentLoaded?.call(_document!);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _error = e;
      widget.onDocumentError?.call(e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _preRenderPages(int currentPage) {
    final document = _document;
    if (document == null) return;

    _cacheService.preRenderPages(
      document: document,
      currentPage: currentPage,
      totalPages: document.pagesCount,
    );
  }

  void _onPageChanged(int pageIndex) {
    final pageNumber = pageIndex + 1;
    widget.controller._pageListenable.value = pageNumber;
    widget.onPageChanged?.call(pageNumber);

    // Pre-render adjacent pages
    _preRenderPages(pageNumber);
  }

  void _onPageRendered(int pageNumber) {
    // Trigger pre-rendering after the first page renders
    if (!_initialPreRenderDone && pageNumber == widget.controller.initialPage) {
      _initialPreRenderDone = true;
      _preRenderPages(pageNumber);
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_document == null) {
      return const Center(child: Text('Failed to load document'));
    }

    return PageView.builder(
      controller: widget.controller._pageController!,
      scrollDirection: widget.scrollDirection,
      pageSnapping: widget.pageSnapping,
      physics: widget.physics,
      itemCount: _document!.pagesCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return _CachedPdfPage(
          document: _document!,
          pageNumber: index + 1,
          backgroundDecoration: widget.backgroundDecoration,
          onPageRendered: _onPageRendered,
        );
      },
    );
  }
}

/// A single PDF page with caching support
class _CachedPdfPage extends StatefulWidget {
  const _CachedPdfPage({
    required this.document,
    required this.pageNumber,
    this.backgroundDecoration,
    this.onPageRendered,
  });

  final PdfDocument document;
  final int pageNumber;
  final BoxDecoration? backgroundDecoration;
  final void Function(int pageNumber)? onPageRendered;

  @override
  State<_CachedPdfPage> createState() => _CachedPdfPageState();
}

class _CachedPdfPageState extends State<_CachedPdfPage> {
  final _cacheService = PdfPageCacheService.instance;
  CachedPageImage? _pageImage;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(_CachedPdfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.document.id != widget.document.id) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Check cache first
    final cached = _cacheService.getCachedPage(
      widget.document.id,
      widget.pageNumber,
    );

    if (cached != null) {
      if (mounted) {
        setState(() {
          _pageImage = cached;
          _isLoading = false;
        });
        widget.onPageRendered?.call(widget.pageNumber);
      }
      return;
    }

    // Render and cache the page
    try {
      final image = await _cacheService.renderAndCachePage(
        document: widget.document,
        pageNumber: widget.pageNumber,
      );

      if (mounted) {
        setState(() {
          _pageImage = image;
          _isLoading = false;
        });
        widget.onPageRendered?.call(widget.pageNumber);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: widget.backgroundDecoration,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        decoration: widget.backgroundDecoration,
        child: Center(child: Text('Error: $_error')),
      );
    }

    if (_pageImage == null) {
      return Container(
        decoration: widget.backgroundDecoration,
        child: const Center(child: Text('Failed to render page')),
      );
    }

    return Container(
      decoration: widget.backgroundDecoration,
      child: PhotoView(
        imageProvider: MemoryImage(_pageImage!.bytes),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained * 3.0,
        initialScale: PhotoViewComputedScale.contained,
        backgroundDecoration:
            widget.backgroundDecoration ??
            const BoxDecoration(color: Colors.black),
        heroAttributes: PhotoViewHeroAttributes(
          tag: '${widget.document.id}-${widget.pageNumber}',
        ),
      ),
    );
  }
}

/// Controller for CachedPdfView
class CachedPdfController {
  CachedPdfController({
    required this.document,
    this.initialPage = 1,
    this.viewportFraction = 1.0,
  }) : assert(viewportFraction > 0.0);

  final Future<PdfDocument> document;
  final int initialPage;
  final double viewportFraction;

  PdfDocument? _document;
  PageController? _pageController;
  final ValueNotifier<int> _pageListenable = ValueNotifier(1);

  /// Current page number (1-indexed)
  int get page => _pageListenable.value;

  /// Total page count
  int? get pagesCount => _document?.pagesCount;

  /// Notifier for page changes
  ValueNotifier<int> get pageListenable => _pageListenable;

  void _attach(PdfDocument document) {
    _document = document;
    _pageController = PageController(
      initialPage: initialPage - 1,
      viewportFraction: viewportFraction,
    );
    _pageListenable.value = initialPage;
  }

  void _detach() {}

  /// Jump to a specific page (1-indexed)
  void jumpToPage(int page) {
    _pageController?.jumpToPage(page - 1);
  }

  /// Animate to a specific page (1-indexed)
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) {
    if (_pageController == null) return Future.value();
    return _pageController!.animateToPage(
      page - 1,
      duration: duration,
      curve: curve,
    );
  }

  /// Navigate to next page
  Future<void> nextPage({required Duration duration, required Curve curve}) {
    if (_pageController == null) return Future.value();
    final currentPage = _pageController!.page?.round() ?? 0;
    return _pageController!.animateToPage(
      currentPage + 1,
      duration: duration,
      curve: curve,
    );
  }

  /// Navigate to previous page
  Future<void> previousPage({
    required Duration duration,
    required Curve curve,
  }) {
    if (_pageController == null) return Future.value();
    final currentPage = _pageController!.page?.round() ?? 0;
    return _pageController!.animateToPage(
      currentPage - 1,
      duration: duration,
      curve: curve,
    );
  }

  /// Dispose the controller
  void dispose() {
    _pageController?.dispose();
    _pageListenable.dispose();

    // Clear cache for this document
    if (_document != null) {
      PdfPageCacheService.instance.clearDocument(_document!.id);
    }
  }
}
