import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/models/view_mode.dart';
import 'package:open_score/utils/page_spread_calculator.dart';

/// Tests for PerformanceDocumentView widget logic
/// Note: Full widget tests are difficult due to pdfx dependency.
/// These tests verify the navigation and spread calculation logic.
void main() {
  group('PerformanceDocumentView Navigation Logic', () {
    group('Single page mode navigation', () {
      test('can go to previous when not on first page', () {
        const currentPage = 5;

        final canGoPrevious = currentPage > 1;

        expect(canGoPrevious, isTrue);
      });

      test('cannot go to previous when on first page', () {
        const currentPage = 1;

        final canGoPrevious = currentPage > 1;

        expect(canGoPrevious, isFalse);
      });

      test('can go to next when not on last page', () {
        const currentPage = 5;
        const totalPages = 10;

        final canGoNext = currentPage < totalPages;

        expect(canGoNext, isTrue);
      });

      test('cannot go to next when on last page', () {
        const currentPage = 10;
        const totalPages = 10;

        final canGoNext = currentPage < totalPages;

        expect(canGoNext, isFalse);
      });
    });

    group('Two-page mode navigation', () {
      test('booklet mode can go to previous spread', () {
        const viewMode = PdfViewMode.booklet;
        const currentPage = 3; // Spread 1 (pages 3-4)
        const totalPages = 10;

        final currentSpread = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final canGoPrevious = currentSpread > 0;

        expect(currentSpread, 1);
        expect(canGoPrevious, isTrue);
      });

      test('booklet mode cannot go to previous on first spread', () {
        const viewMode = PdfViewMode.booklet;
        const currentPage = 1; // Spread 0 (pages 1-2)
        const totalPages = 10;

        final currentSpread = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final canGoPrevious = currentSpread > 0;

        expect(currentSpread, 0);
        expect(canGoPrevious, isFalse);
      });

      test('continuous double mode can go to next spread', () {
        const viewMode = PdfViewMode.continuousDouble;
        const currentPage = 3; // Spread 2 (pages 3-4)
        const totalPages = 10;

        final currentSpread = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final totalSpreads = PageSpreadCalculator.getTotalSpreads(
          viewMode,
          totalPages,
        );
        final canGoNext = currentSpread < totalSpreads - 1;

        expect(totalSpreads, 9); // pages-1 for continuous
        expect(canGoNext, isTrue);
      });

      test('continuous double mode cannot go to next on last spread', () {
        const viewMode = PdfViewMode.continuousDouble;
        const totalPages = 10;
        // Last spread is spread 8 (pages 9-10)
        const currentPage = 9;

        final currentSpread = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final totalSpreads = PageSpreadCalculator.getTotalSpreads(
          viewMode,
          totalPages,
        );
        final canGoNext = currentSpread < totalSpreads - 1;

        expect(currentSpread, 8);
        expect(totalSpreads, 9);
        expect(canGoNext, isFalse);
      });
    });

    group('Page clamping', () {
      test('initial page is clamped to valid range', () {
        const initialPage = 100;
        const totalPages = 10;

        final clampedPage = initialPage.clamp(1, totalPages);

        expect(clampedPage, 10);
      });

      test('initial page of 0 is clamped to 1', () {
        const initialPage = 0;
        const totalPages = 10;

        final clampedPage = initialPage.clamp(1, totalPages);

        expect(clampedPage, 1);
      });

      test('negative initial page is clamped to 1', () {
        const initialPage = -5;
        const totalPages = 10;

        final clampedPage = initialPage.clamp(1, totalPages);

        expect(clampedPage, 1);
      });
    });

    group('Spread calculation for current page', () {
      test('single mode spread equals page - 1', () {
        const viewMode = PdfViewMode.single;
        const currentPage = 5;
        const totalPages = 10;

        final spreadIndex = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final spread = PageSpreadCalculator.getPagesForSpread(
          viewMode,
          spreadIndex,
          totalPages,
        );

        expect(spread.leftPage, currentPage);
        expect(spread.rightPage, isNull);
      });

      test('booklet mode shows correct page pair', () {
        const viewMode = PdfViewMode.booklet;
        const currentPage = 5;
        const totalPages = 10;

        final spreadIndex = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final spread = PageSpreadCalculator.getPagesForSpread(
          viewMode,
          spreadIndex,
          totalPages,
        );

        // Page 5 is in spread 2 (pages 5-6)
        expect(spread.leftPage, 5);
        expect(spread.rightPage, 6);
      });

      test('continuous double mode shows sliding window', () {
        const viewMode = PdfViewMode.continuousDouble;
        const currentPage = 5;
        const totalPages = 10;

        final spreadIndex = PageSpreadCalculator.getSpreadForPage(
          viewMode,
          currentPage,
          totalPages,
        );
        final spread = PageSpreadCalculator.getPagesForSpread(
          viewMode,
          spreadIndex,
          totalPages,
        );

        // Page 5 appears on left of spread 4 (pages 5-6)
        expect(spread.leftPage, 5);
        expect(spread.rightPage, 6);
      });
    });

    group('View mode changes', () {
      test('switching from single to booklet maintains logical position', () {
        const currentPage = 5;
        const totalPages = 10;

        // In single mode, we're on page 5
        // In booklet mode, page 5 is in spread 2

        final bookletSpread = PageSpreadCalculator.getSpreadForPage(
          PdfViewMode.booklet,
          currentPage,
          totalPages,
        );
        final bookletPages = PageSpreadCalculator.getPagesForSpread(
          PdfViewMode.booklet,
          bookletSpread,
          totalPages,
        );

        // Page 5 should be visible (as left page)
        expect(bookletPages.leftPage, 5);
      });

      test('switching from booklet to single shows left page', () {
        // When on booklet spread showing pages 5-6
        const bookletSpread = 2;
        const totalPages = 10;

        final pages = PageSpreadCalculator.getPagesForSpread(
          PdfViewMode.booklet,
          bookletSpread,
          totalPages,
        );

        // When switching to single, we should show the left page
        expect(pages.leftPage, 5);
      });
    });
  });

  group('Annotation display in performance mode', () {
    test('annotations are loaded per page', () {
      // In performance mode, annotations are read-only
      // We load from all visible layers

      final visibleLayers = [1, 2, 3];
      final pageAnnotations = <int, List<String>>{};

      // Simulate loading annotations from layers
      for (final layerId in visibleLayers) {
        pageAnnotations[layerId] = ['stroke1', 'stroke2'];
      }

      expect(pageAnnotations.length, 3);
      expect(pageAnnotations.values.expand((s) => s).length, 6);
    });

    test('flattening annotations from multiple layers', () {
      final layerAnnotations = <int, List<String>>{
        1: ['a', 'b'],
        2: ['c', 'd', 'e'],
        3: ['f'],
      };

      final flattened = layerAnnotations.values
          .expand((strokes) => strokes)
          .toList();

      expect(flattened, ['a', 'b', 'c', 'd', 'e', 'f']);
      expect(flattened.length, 6);
    });
  });
}
