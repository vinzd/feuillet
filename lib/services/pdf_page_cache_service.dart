import 'dart:async';
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

    // Pre-render each page in background
    for (final pageNumber in pagesToRender) {
      final key = PageCacheKey(documentId, pageNumber);

      // Skip if already cached or being rendered
      if (_cache.containsKey(key) || _rendering.contains(key)) {
        continue;
      }

      // Mark as rendering
      _rendering.add(key);

      // Render in background
      unawaited(
        _renderPage(document: document, pageNumber: pageNumber, scale: scale)
            .then((_) {
              _rendering.remove(key);
            })
            .catchError((error) {
              _rendering.remove(key);
              debugPrint('Error pre-rendering page $pageNumber: $error');
            }),
      );
    }
  }

  /// Render a single page and cache it
  Future<CachedPageImage?> _renderPage({
    required PdfDocument document,
    required int pageNumber,
    required double scale,
  }) async {
    final documentId = document.id;
    final key = PageCacheKey(documentId, pageNumber);

    // Check if already cached (might have been cached while waiting)
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    try {
      // Get the page
      final page = await document.getPage(pageNumber);

      try {
        // Render the page
        final image = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.jpeg,
          backgroundColor: '#ffffff',
          quality: 85,
        );

        if (image != null) {
          final cachedImage = CachedPageImage(
            bytes: image.bytes,
            width: image.width ?? (page.width * scale).round(),
            height: image.height ?? (page.height * scale).round(),
          );

          _cache[key] = cachedImage;
          _evictOldPages(documentId);

          return cachedImage;
        }
      } finally {
        await page.close();
      }
    } catch (e) {
      debugPrint('Error rendering page $pageNumber: $e');
    }

    return null;
  }

  /// Render a page and return it (also caches it)
  Future<CachedPageImage?> renderAndCachePage({
    required PdfDocument document,
    required int pageNumber,
    double scale = 2.0,
  }) async {
    final documentId = document.id;
    final key = PageCacheKey(documentId, pageNumber);

    // Return cached version if available
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // Mark as rendering
    _rendering.add(key);

    try {
      return await _renderPage(
        document: document,
        pageNumber: pageNumber,
        scale: scale,
      );
    } finally {
      _rendering.remove(key);
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
  }
}
