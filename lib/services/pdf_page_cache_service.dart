import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

/// Cache key for a rendered PDF page
class PageCacheKey {
  final String documentId;
  final int pageNumber;

  PageCacheKey(this.documentId, this.pageNumber);

  @override
  bool operator ==(Object other) =>
      other is PageCacheKey &&
      other.documentId == documentId &&
      other.pageNumber == pageNumber;

  @override
  int get hashCode => Object.hash(documentId, pageNumber);

  @override
  String toString() => 'PageCacheKey($documentId, $pageNumber)';
}

/// Cached page image data
class CachedPageImage {
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime cachedAt;

  CachedPageImage({
    required this.bytes,
    required this.width,
    required this.height,
  }) : cachedAt = DateTime.now();
}

/// Service for caching and pre-rendering PDF pages
class PdfPageCacheService {
  static PdfPageCacheService? _instance;
  static PdfPageCacheService get instance =>
      _instance ??= PdfPageCacheService._();
  PdfPageCacheService._();

  /// Cache of rendered page images
  final Map<PageCacheKey, CachedPageImage> _cache = {};

  /// Set of pages currently being rendered
  final Set<PageCacheKey> _rendering = {};

  /// Queue of render requests processed sequentially.
  /// Priority (on-demand) requests are added to the front.
  final ListQueue<_RenderRequest> _renderQueue = ListQueue();

  /// Whether the render queue is currently being processed
  bool _isProcessingQueue = false;

  /// Maximum number of pages to keep in cache per document
  static const int maxPagesPerDocument = 25;

  /// Number of pages to pre-render ahead and behind current page
  static const int preRenderRadius = 10;

  /// Get a cached page image
  CachedPageImage? getCachedPage(String documentId, int pageNumber) {
    final key = PageCacheKey(documentId, pageNumber);
    return _cache[key];
  }

  /// Check if a page is cached
  bool isPageCached(String documentId, int pageNumber) {
    return _cache.containsKey(PageCacheKey(documentId, pageNumber));
  }

  /// Check if a page is currently being rendered
  bool isPageRendering(String documentId, int pageNumber) {
    return _rendering.contains(PageCacheKey(documentId, pageNumber));
  }

  /// Cache a rendered page image
  void cachePage(String documentId, int pageNumber, CachedPageImage image) {
    final key = PageCacheKey(documentId, pageNumber);
    _cache[key] = image;
    _evictOldPages(documentId);
  }

  /// Pre-render pages around the current page
  Future<void> preRenderPages({
    required PdfDocument document,
    required int currentPage,
    required int totalPages,
    double scale = 2.0,
  }) async {
    final documentId = document.id;

    // Calculate pages to pre-render (current page ± radius)
    final pagesToRender = <int>[];
    for (int offset = 1; offset <= preRenderRadius; offset++) {
      // Prioritize forward pages first
      if (currentPage + offset <= totalPages) {
        pagesToRender.add(currentPage + offset);
      }
      if (currentPage - offset >= 1) {
        pagesToRender.add(currentPage - offset);
      }
    }

    // Clear any stale queued non-priority requests for this document
    _renderQueue.removeWhere(
      (r) => r.documentId == documentId && r.completer == null,
    );

    // Enqueue pages for sequential rendering (at the back)
    for (final pageNumber in pagesToRender) {
      final key = PageCacheKey(documentId, pageNumber);

      // Skip if already cached or being rendered
      if (_cache.containsKey(key) || _rendering.contains(key)) {
        continue;
      }

      _renderQueue.addLast(
        _RenderRequest(
          document: document,
          pageNumber: pageNumber,
          scale: scale,
        ),
      );
    }

    // Start processing the queue if not already running
    _startProcessing();
  }

  /// Render a page on-demand with priority and return it (also caches it)
  Future<CachedPageImage?> renderAndCachePage({
    required PdfDocument document,
    required int pageNumber,
    double scale = 2.0,
  }) async {
    final key = PageCacheKey(document.id, pageNumber);

    // Return cached version if available
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // Check if this page is already queued with a completer (another caller waiting)
    for (final req in _renderQueue) {
      if (req.documentId == document.id &&
          req.pageNumber == pageNumber &&
          req.completer != null) {
        return req.completer!.future;
      }
    }

    // Create a priority request with a completer so we can return the result
    final completer = Completer<CachedPageImage?>();
    final request = _RenderRequest(
      document: document,
      pageNumber: pageNumber,
      scale: scale,
      completer: completer,
    );

    // Insert at front of queue for priority processing
    _renderQueue.addFirst(request);

    // Start processing if not already running
    _startProcessing();

    return completer.future;
  }

  void _startProcessing() {
    if (_isProcessingQueue || _renderQueue.isEmpty) return;
    _isProcessingQueue = true;
    unawaited(_processQueue());
  }

  Future<void> _processQueue() async {
    while (_renderQueue.isNotEmpty) {
      final request = _renderQueue.removeFirst();
      final key = PageCacheKey(request.documentId, request.pageNumber);

      // Skip if already cached while waiting in queue
      if (_cache.containsKey(key)) {
        request.completer?.complete(_cache[key]);
        continue;
      }

      // Skip non-priority requests if already being rendered elsewhere
      if (_rendering.contains(key) && request.completer == null) {
        continue;
      }

      _rendering.add(key);
      try {
        final result = await _renderPage(
          document: request.document,
          pageNumber: request.pageNumber,
          scale: request.scale,
        );
        request.completer?.complete(result);
      } catch (error) {
        debugPrint('Error rendering page ${request.pageNumber}: $error');
        request.completer?.complete(null);
      } finally {
        _rendering.remove(key);
      }
    }
    _isProcessingQueue = false;
  }

  /// Render a single page and cache it
  Future<CachedPageImage?> _renderPage({
    required PdfDocument document,
    required int pageNumber,
    required double scale,
  }) async {
    final page = await document.getPage(pageNumber);

    try {
      final image = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
        quality: 85,
      );

      if (image == null) return null;

      final cachedImage = CachedPageImage(
        bytes: image.bytes,
        width: image.width ?? (page.width * scale).round(),
        height: image.height ?? (page.height * scale).round(),
      );

      final key = PageCacheKey(document.id, pageNumber);
      _cache[key] = cachedImage;
      _evictOldPages(document.id);

      return cachedImage;
    } finally {
      await page.close();
    }
  }

  /// Evict old pages to stay within memory limits
  void _evictOldPages(String documentId) {
    // Get all pages for this document
    final docPages = _cache.entries
        .where((e) => e.key.documentId == documentId)
        .toList();

    // If under limit, no eviction needed
    if (docPages.length <= maxPagesPerDocument) {
      return;
    }

    // Sort by cache time (oldest first)
    docPages.sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

    // Remove oldest pages until under limit
    final toRemove = docPages.length - maxPagesPerDocument;
    for (int i = 0; i < toRemove; i++) {
      _cache.remove(docPages[i].key);
    }
  }

  /// Clear cache for a specific document
  void clearDocument(String documentId) {
    _cache.removeWhere((key, _) => key.documentId == documentId);
  }

  /// Clear entire cache
  void clearAll() {
    _cache.clear();
    _rendering.clear();
    _renderQueue.clear();
  }
}

/// A queued render request
class _RenderRequest {
  final PdfDocument document;
  final int pageNumber;
  final double scale;

  /// If non-null, this is an on-demand (priority) request and the completer
  /// will be completed with the result.
  final Completer<CachedPageImage?>? completer;

  _RenderRequest({
    required this.document,
    required this.pageNumber,
    required this.scale,
    this.completer,
  });

  String get documentId => document.id;
}
