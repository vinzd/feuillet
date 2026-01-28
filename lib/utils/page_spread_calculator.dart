import '../models/view_mode.dart';

/// Utility class for calculating page spreads in different view modes.
///
/// A "spread" is one or two pages displayed together. In single mode,
/// each spread is one page. In two-page modes, each spread is two pages.
class PageSpreadCalculator {
  PageSpreadCalculator._();

  /// Get the total number of spreads for a document in the given view mode.
  ///
  /// - Single: totalPages spreads (one page per spread)
  /// - Booklet: ceil(totalPages / 2) spreads
  /// - ContinuousDouble: totalPages - 1 spreads (or 1 if single page)
  static int getTotalSpreads(PdfViewMode mode, int totalPages) {
    if (totalPages <= 0) return 0;
    if (totalPages == 1) return 1;

    switch (mode) {
      case PdfViewMode.single:
        return totalPages;
      case PdfViewMode.booklet:
        return (totalPages + 1) ~/ 2;
      case PdfViewMode.continuousDouble:
        return totalPages - 1;
    }
  }

  /// Get the page numbers for a given spread index (0-indexed).
  ///
  /// Returns a record with (leftPage, rightPage) where pages are 1-indexed.
  /// rightPage may be null if there's only one page to display.
  static ({int leftPage, int? rightPage}) getPagesForSpread(
    PdfViewMode mode,
    int spreadIndex,
    int totalPages,
  ) {
    if (totalPages <= 0 || spreadIndex < 0) {
      return (leftPage: 1, rightPage: null);
    }

    switch (mode) {
      case PdfViewMode.single:
        final page = spreadIndex + 1;
        return (leftPage: page.clamp(1, totalPages), rightPage: null);

      case PdfViewMode.booklet:
        final leftPage = spreadIndex * 2 + 1;
        final rightPage = leftPage + 1;
        return (
          leftPage: leftPage.clamp(1, totalPages),
          rightPage: rightPage <= totalPages ? rightPage : null,
        );

      case PdfViewMode.continuousDouble:
        final leftPage = spreadIndex + 1;
        final rightPage = leftPage + 1;
        return (
          leftPage: leftPage.clamp(1, totalPages),
          rightPage: rightPage <= totalPages ? rightPage : null,
        );
    }
  }

  /// Get the spread index containing a specific page (1-indexed).
  ///
  /// Returns 0-indexed spread index.
  static int getSpreadForPage(
    PdfViewMode mode,
    int pageNumber,
    int totalPages,
  ) {
    if (totalPages <= 0 || pageNumber <= 0) return 0;

    final page = pageNumber.clamp(1, totalPages);

    switch (mode) {
      case PdfViewMode.single:
        return page - 1;

      case PdfViewMode.booklet:
        // Pages 1-2 -> spread 0, pages 3-4 -> spread 1, etc.
        return (page - 1) ~/ 2;

      case PdfViewMode.continuousDouble:
        // Page 1 is only in spread 0
        // Page 2 is in spread 0 and 1
        // Page 3 is in spread 1 and 2
        // We return the spread where the page is on the left
        if (page == totalPages && totalPages > 1) {
          // Last page is only on the right of the last spread
          return totalPages - 2;
        }
        return page - 1;
    }
  }

  /// Get which side a page appears on in a spread.
  ///
  /// Returns PageSide.left or PageSide.right.
  static PageSide getPageSide(
    PdfViewMode mode,
    int pageNumber,
    int spreadIndex,
  ) {
    switch (mode) {
      case PdfViewMode.single:
        return PageSide.left;

      case PdfViewMode.booklet:
        // Odd pages on left, even pages on right
        return pageNumber.isOdd ? PageSide.left : PageSide.right;

      case PdfViewMode.continuousDouble:
        // First page of spread is left, second is right
        final leftPage = spreadIndex + 1;
        return pageNumber == leftPage ? PageSide.left : PageSide.right;
    }
  }
}
