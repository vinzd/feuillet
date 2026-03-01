import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Tests to ensure pre-rendering is properly integrated in the PDF viewer.
///
/// These tests verify at compile-time and source-level that the pre-rendering
/// functionality is not accidentally removed. The pre-rendering was lost once
/// during the two-page view implementation (commit 18722f9) and restored later.
/// These tests prevent that regression from happening again.
void main() {
  group('Document Viewer Pre-rendering Integration', () {
    late String pdfViewerSource;
    late List<String> sourceLines;

    setUpAll(() {
      // Read the PDF viewer source code
      final file = File('lib/screens/document_viewer_screen.dart');
      pdfViewerSource = file.readAsStringSync();
      sourceLines = pdfViewerSource.split('\n');
    });

    test('document_viewer_screen.dart imports pdf_page_cache_service.dart', () {
      expect(
        pdfViewerSource.contains(
          "import '../services/pdf_page_cache_service.dart'",
        ),
        isTrue,
        reason:
            'DocumentViewerScreen must import pdf_page_cache_service.dart for pre-rendering. '
            'This import was accidentally lost in the two-page view implementation.',
      );
    });

    test('document_viewer_screen.dart defines _preRenderPages method', () {
      expect(
        pdfViewerSource.contains('void _preRenderPages()'),
        isTrue,
        reason:
            'DocumentViewerScreen must have a _preRenderPages() method to trigger '
            'background page caching for faster navigation.',
      );
    });

    test('_preRenderPages calls PdfPageCacheService.instance.preRenderPages', () {
      expect(
        pdfViewerSource.contains('PdfPageCacheService.instance.preRenderPages'),
        isTrue,
        reason:
            '_preRenderPages must use PdfPageCacheService.instance.preRenderPages '
            'to actually trigger background page rendering.',
      );
    });

    test('_preRenderPages is called at least 4 times in the source', () {
      // Count occurrences of _preRenderPages() calls (not the definition)
      final callPattern = RegExp(r'_preRenderPages\(\);');
      final matches = callPattern.allMatches(pdfViewerSource);

      // Should be called:
      // 1. In _goToPreviousPage
      // 2. In _goToNextPage
      // 3. In _onPageChanged
      // 4. In _onViewModeChanged
      // (NOT in _initializePdf — CachedPdfView handles initial pre-rendering)
      expect(
        matches.length,
        greaterThanOrEqualTo(4),
        reason:
            '_preRenderPages() should be called in at least 4 places: '
            'on previous page, on next page, on page changed, and on view mode changed.',
      );
    });

    test('_preRenderPages is called in _goToNextPage', () {
      // Find the _goToNextPage method and check it contains _preRenderPages()
      final methodStartIndex = sourceLines.indexWhere(
        (line) => line.contains('void _goToNextPage()'),
      );
      expect(
        methodStartIndex,
        greaterThan(0),
        reason: '_goToNextPage must exist',
      );

      // Look for _preRenderPages() call within the next 40 lines (method body)
      final methodBody = sourceLines.skip(methodStartIndex).take(40).join('\n');

      expect(
        methodBody.contains('_preRenderPages()'),
        isTrue,
        reason:
            '_goToNextPage must call _preRenderPages() to pre-cache pages when navigating forward.',
      );
    });

    test('_preRenderPages is called in _goToPreviousPage', () {
      // Find the _goToPreviousPage method
      final methodStartIndex = sourceLines.indexWhere(
        (line) => line.contains('void _goToPreviousPage()'),
      );
      expect(
        methodStartIndex,
        greaterThan(0),
        reason: '_goToPreviousPage must exist',
      );

      // Look for _preRenderPages() call within the method body
      final methodBody = sourceLines.skip(methodStartIndex).take(40).join('\n');

      expect(
        methodBody.contains('_preRenderPages()'),
        isTrue,
        reason:
            '_goToPreviousPage must call _preRenderPages() to pre-cache pages when navigating backward.',
      );
    });

    test('_preRenderPages is called in _onPageChanged', () {
      // Find the _onPageChanged method
      final methodStartIndex = sourceLines.indexWhere(
        (line) => line.contains('void _onPageChanged('),
      );
      expect(
        methodStartIndex,
        greaterThan(0),
        reason: '_onPageChanged must exist',
      );

      // Look for _preRenderPages() call within the method body
      final methodBody = sourceLines.skip(methodStartIndex).take(15).join('\n');

      expect(
        methodBody.contains('_preRenderPages()'),
        isTrue,
        reason:
            '_onPageChanged must call _preRenderPages() to pre-cache pages when page changes.',
      );
    });

    test('_preRenderPages is called in _onViewModeChanged', () {
      // Find the _onViewModeChanged method
      final methodStartIndex = sourceLines.indexWhere(
        (line) => line.contains('void _onViewModeChanged('),
      );
      expect(
        methodStartIndex,
        greaterThan(0),
        reason: '_onViewModeChanged must exist',
      );

      // Look for _preRenderPages() call within the method body
      final methodBody = sourceLines.skip(methodStartIndex).take(15).join('\n');

      expect(
        methodBody.contains('_preRenderPages()'),
        isTrue,
        reason:
            '_onViewModeChanged must call _preRenderPages() to pre-cache pages when view mode changes.',
      );
    });

    test(
      '_preRenderPages is called in _initializePdf for initial pre-rendering',
      () {
        // Pre-rendering on initial load is handled by CachedPdfView's
        // onPageRendered callback after the first page renders successfully.
        // Pre-rendering is now safe to call in _initializePdf because
        // renderAndCachePage (on-demand) has priority over pre-rendering
        // in the serialized render queue.
        final methodStartIndex = sourceLines.indexWhere(
          (line) => line.contains('Future<void> _initializePdf()'),
        );
        expect(
          methodStartIndex,
          greaterThan(0),
          reason: '_initializePdf must exist',
        );

        final methodBody = sourceLines
            .skip(methodStartIndex)
            .take(70)
            .join('\n');

        expect(
          methodBody.contains('_preRenderPages()'),
          isTrue,
          reason:
              '_initializePdf should call _preRenderPages() to start '
              'pre-rendering adjacent pages after the initial page loads.',
        );
      },
    );
  });

  group('Pre-rendering method implementation', () {
    late String pdfViewerSource;

    setUpAll(() {
      final file = File('lib/screens/document_viewer_screen.dart');
      pdfViewerSource = file.readAsStringSync();
    });

    test('_preRenderPages checks for null _pdfDocument', () {
      // The null guard may use either a direct check or a local variable pattern
      final hasNullGuard =
          pdfViewerSource.contains('if (_pdfDocument == null) return') ||
          pdfViewerSource.contains('if (pdfDocument == null) return');
      expect(
        hasNullGuard,
        isTrue,
        reason:
            '_preRenderPages must guard against null _pdfDocument to prevent errors.',
      );
    });

    test('_preRenderPages uses _getCurrentSpread for page calculation', () {
      expect(
        pdfViewerSource.contains('_getCurrentSpread()'),
        isTrue,
        reason:
            '_preRenderPages should use _getCurrentSpread() to determine '
            'which page to base pre-rendering on.',
      );
    });
  });
}
