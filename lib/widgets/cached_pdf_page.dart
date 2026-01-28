import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../services/pdf_page_cache_service.dart';

/// A single PDF page with caching support.
///
/// This widget renders a single page from a PDF document using the
/// [PdfPageCacheService] for efficient caching and pre-rendering.
class CachedPdfPage extends StatefulWidget {
  const CachedPdfPage({
    required this.document,
    required this.pageNumber,
    this.backgroundDecoration,
    this.onPageRendered,
    this.fit = BoxFit.contain,
    this.annotationOverlay,
    super.key,
  });

  /// The PDF document to render a page from
  final PdfDocument document;

  /// The page number to render (1-indexed)
  final int pageNumber;

  /// Background decoration for the page container
  final BoxDecoration? backgroundDecoration;

  /// Callback when the page has been rendered
  final void Function(int pageNumber)? onPageRendered;

  /// How the page image should fit within its container
  final BoxFit fit;

  /// Optional annotation overlay widget to display on top of the PDF.
  /// When provided, both PDF and annotations are scaled together using FittedBox,
  /// ensuring consistent coordinate systems across different view modes.
  final Widget? annotationOverlay;

  @override
  State<CachedPdfPage> createState() => _CachedPdfPageState();
}

class _CachedPdfPageState extends State<CachedPdfPage> {
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
  void didUpdateWidget(CachedPdfPage oldWidget) {
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

    // If no annotation overlay, use simple image display
    if (widget.annotationOverlay == null) {
      return Container(
        decoration: widget.backgroundDecoration,
        child: Center(child: Image.memory(_pageImage!.bytes, fit: widget.fit)),
      );
    }

    // With annotation overlay: use FittedBox to scale PDF and annotations together
    // This ensures consistent coordinate systems across different view modes
    return Container(
      decoration: widget.backgroundDecoration,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _pageImage!.width.toDouble(),
            height: _pageImage!.height.toDouble(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // PDF image at natural size
                Image.memory(
                  _pageImage!.bytes,
                  fit: BoxFit.fill, // Fills the SizedBox exactly
                ),
                // Annotation overlay fills the same space
                widget.annotationOverlay!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
