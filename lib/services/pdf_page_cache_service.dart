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

  /// Maximum pixel dimension (width or height) for rendered pages.
  /// Pages whose native size already exceeds this at the requested scale
  /// are downscaled to fit, avoiding needlessly large renders for
  /// high-resolution source PDFs.
  static const int maxRenderDimension = 3000;

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
    debugPrint(
      '[PreRender] preRenderPages called: docId=$documentId, '
      'currentPage=$currentPage, totalPages=$totalPages, scale=$scale',
    );

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

    debugPrint(
      '[PreRender] pages to consider: $pagesToRender '
      '(${pagesToRender.length} pages)',
    );

    // Clear any stale queued non-priority requests for this document
    final queueSizeBefore = _renderQueue.length;
    _renderQueue.removeWhere(
      (r) => r.documentId == documentId && r.completer == null,
    );
    final staleRemoved = queueSizeBefore - _renderQueue.length;
    if (staleRemoved > 0) {
      debugPrint('[PreRender] cleared $staleRemoved stale queued requests');
    }

    // Enqueue pages for sequential rendering (at the back)
    int skippedCached = 0;
    int skippedRendering = 0;
    int enqueued = 0;
    for (final pageNumber in pagesToRender) {
      final key = PageCacheKey(documentId, pageNumber);

      // Skip if already cached or being rendered
      if (_cache.containsKey(key)) {
        skippedCached++;
        continue;
      }
      if (_rendering.contains(key)) {
        skippedRendering++;
        continue;
      }

      _renderQueue.addLast(
        _RenderRequest(
          document: document,
          pageNumber: pageNumber,
          scale: scale,
        ),
      );
      enqueued++;
    }

    debugPrint(
      '[PreRender] enqueued=$enqueued, skippedCached=$skippedCached, '
      'skippedRendering=$skippedRendering, queueSize=${_renderQueue.length}',
    );

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
      debugPrint(
        '[PreRender] renderAndCachePage: page $pageNumber already cached',
      );
      return _cache[key];
    }

    // Check if this page is already queued with a completer (another caller waiting)
    for (final req in _renderQueue) {
      if (req.documentId == document.id &&
          req.pageNumber == pageNumber &&
          req.completer != null) {
        debugPrint(
          '[PreRender] renderAndCachePage: page $pageNumber already queued '
          'with completer, reusing',
        );
        return req.completer!.future;
      }
    }

    debugPrint(
      '[PreRender] renderAndCachePage: priority render for page $pageNumber '
      '(docId=${document.id})',
    );

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
    if (_isProcessingQueue) {
      debugPrint(
        '[PreRender] _startProcessing: already processing '
        '(queue=${_renderQueue.length})',
      );
      return;
    }
    if (_renderQueue.isEmpty) {
      debugPrint('[PreRender] _startProcessing: queue empty, nothing to do');
      return;
    }
    debugPrint(
      '[PreRender] _startProcessing: beginning queue processing '
      '(${_renderQueue.length} items)',
    );
    _isProcessingQueue = true;
    unawaited(_processQueue());
  }

  Future<void> _processQueue() async {
    int rendered = 0;
    int skipped = 0;
    final stopwatch = Stopwatch()..start();

    while (_renderQueue.isNotEmpty) {
      final request = _renderQueue.removeFirst();
      final key = PageCacheKey(request.documentId, request.pageNumber);
      final isPriority = request.completer != null;

      // Skip if already cached while waiting in queue
      if (_cache.containsKey(key)) {
        request.completer?.complete(_cache[key]);
        skipped++;
        continue;
      }

      // Skip non-priority requests if already being rendered elsewhere
      if (_rendering.contains(key) && !isPriority) {
        skipped++;
        continue;
      }

      _rendering.add(key);
      try {
        final pageStopwatch = Stopwatch()..start();
        final result = await _renderPage(
          document: request.document,
          pageNumber: request.pageNumber,
          scale: request.scale,
        );
        pageStopwatch.stop();

        if (result != null) {
          debugPrint(
            '[PreRender] rendered page ${request.pageNumber} '
            '(${request.documentId}) in ${pageStopwatch.elapsedMilliseconds}ms '
            '— ${result.width}x${result.height}, '
            '${(result.bytes.length / 1024).toStringAsFixed(0)}KB'
            '${isPriority ? " [PRIORITY]" : ""}',
          );
        } else {
          debugPrint(
            '[PreRender] page ${request.pageNumber} '
            '(${request.documentId}) render returned null '
            'after ${pageStopwatch.elapsedMilliseconds}ms',
          );
        }

        rendered++;
        request.completer?.complete(result);
      } catch (error, stack) {
        debugPrint(
          '[PreRender] ERROR rendering page ${request.pageNumber} '
          '(${request.documentId}): $error\n$stack',
        );
        request.completer?.complete(null);
      } finally {
        _rendering.remove(key);
      }
    }

    stopwatch.stop();
    debugPrint(
      '[PreRender] queue finished: rendered=$rendered, skipped=$skipped, '
      'totalTime=${stopwatch.elapsedMilliseconds}ms, '
      'cacheSize=${_cache.length}',
    );
    _isProcessingQueue = false;
  }

  /// Render a single page and cache it
  Future<CachedPageImage?> _renderPage({
    required PdfDocument document,
    required int pageNumber,
    required double scale,
  }) async {
    debugPrint(
      '[PreRender] _renderPage: opening page $pageNumber '
      '(docId=${document.id})',
    );
    final page = await document.getPage(pageNumber);
    debugPrint(
      '[PreRender] _renderPage: page $pageNumber native size='
      '${page.width}x${page.height}, '
      'renderSize=${(page.width * scale).round()}x'
      '${(page.height * scale).round()}',
    );

    try {
      var effectiveScale = scale;
      final maxNative = page.width > page.height ? page.width : page.height;
      if (maxNative * scale > maxRenderDimension) {
        effectiveScale = maxRenderDimension / maxNative;
      }

      final renderWidth = page.width * effectiveScale;
      final renderHeight = page.height * effectiveScale;
      if (effectiveScale != scale) {
        debugPrint(
          '[PreRender] _renderPage: capped scale ${scale}x → '
          '${effectiveScale.toStringAsFixed(2)}x '
          '(${renderWidth.round()}x${renderHeight.round()})',
        );
      }

      final image = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
        quality: 85,
      );

      if (image == null) {
        debugPrint(
          '[PreRender] _renderPage: page.render() returned null '
          'for page $pageNumber',
        );
        return null;
      }

      final cachedImage = CachedPageImage(
        bytes: image.bytes,
        width: image.width ?? renderWidth.round(),
        height: image.height ?? renderHeight.round(),
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
