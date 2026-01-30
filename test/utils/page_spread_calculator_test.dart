import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/view_mode.dart';
import 'package:feuillet/utils/page_spread_calculator.dart';

void main() {
  group('PageSpreadCalculator', () {
    group('getTotalSpreads', () {
      group('single mode', () {
        test('returns 0 for 0 pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.single, 0),
            0,
          );
        });

        test('returns 1 for 1 page', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.single, 1),
            1,
          );
        });

        test('returns totalPages for multiple pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.single, 5),
            5,
          );
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.single, 10),
            10,
          );
        });
      });

      group('booklet mode', () {
        test('returns 0 for 0 pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 0),
            0,
          );
        });

        test('returns 1 for 1 page', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 1),
            1,
          );
        });

        test('returns 1 for 2 pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 2),
            1,
          );
        });

        test('returns ceil(totalPages / 2) for multiple pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 3),
            2,
          );
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 4),
            2,
          );
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 5),
            3,
          );
          expect(
            PageSpreadCalculator.getTotalSpreads(PdfViewMode.booklet, 10),
            5,
          );
        });
      });

      group('continuousDouble mode', () {
        test('returns 0 for 0 pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(
              PdfViewMode.continuousDouble,
              0,
            ),
            0,
          );
        });

        test('returns 1 for 1 page', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(
              PdfViewMode.continuousDouble,
              1,
            ),
            1,
          );
        });

        test('returns totalPages - 1 for multiple pages', () {
          expect(
            PageSpreadCalculator.getTotalSpreads(
              PdfViewMode.continuousDouble,
              2,
            ),
            1,
          );
          expect(
            PageSpreadCalculator.getTotalSpreads(
              PdfViewMode.continuousDouble,
              5,
            ),
            4,
          );
          expect(
            PageSpreadCalculator.getTotalSpreads(
              PdfViewMode.continuousDouble,
              10,
            ),
            9,
          );
        });
      });
    });

    group('getPagesForSpread', () {
      group('single mode', () {
        test('returns single page for each spread', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.single,
            0,
            5,
          );
          expect(result.leftPage, 1);
          expect(result.rightPage, isNull);
        });

        test('returns correct page for different spreads', () {
          expect(
            PageSpreadCalculator.getPagesForSpread(
              PdfViewMode.single,
              0,
              5,
            ).leftPage,
            1,
          );
          expect(
            PageSpreadCalculator.getPagesForSpread(
              PdfViewMode.single,
              2,
              5,
            ).leftPage,
            3,
          );
          expect(
            PageSpreadCalculator.getPagesForSpread(
              PdfViewMode.single,
              4,
              5,
            ).leftPage,
            5,
          );
        });

        test('clamps to totalPages', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.single,
            10,
            5,
          );
          expect(result.leftPage, 5);
        });
      });

      group('booklet mode', () {
        test('spread 0 returns pages 1-2', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.booklet,
            0,
            10,
          );
          expect(result.leftPage, 1);
          expect(result.rightPage, 2);
        });

        test('spread 1 returns pages 3-4', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.booklet,
            1,
            10,
          );
          expect(result.leftPage, 3);
          expect(result.rightPage, 4);
        });

        test('last spread with odd pages has null right page', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.booklet,
            2,
            5,
          );
          expect(result.leftPage, 5);
          expect(result.rightPage, isNull);
        });

        test('handles single page document', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.booklet,
            0,
            1,
          );
          expect(result.leftPage, 1);
          expect(result.rightPage, isNull);
        });
      });

      group('continuousDouble mode', () {
        test('spread 0 returns pages 1-2', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.continuousDouble,
            0,
            10,
          );
          expect(result.leftPage, 1);
          expect(result.rightPage, 2);
        });

        test('spread 1 returns pages 2-3', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.continuousDouble,
            1,
            10,
          );
          expect(result.leftPage, 2);
          expect(result.rightPage, 3);
        });

        test('last spread returns last two pages', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.continuousDouble,
            8,
            10,
          );
          expect(result.leftPage, 9);
          expect(result.rightPage, 10);
        });
      });

      group('edge cases', () {
        test('handles negative spread index', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.single,
            -1,
            5,
          );
          expect(result.leftPage, 1);
          expect(result.rightPage, isNull);
        });

        test('handles zero total pages', () {
          final result = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.single,
            0,
            0,
          );
          expect(result.leftPage, 1);
          expect(result.rightPage, isNull);
        });
      });
    });

    group('getSpreadForPage', () {
      group('single mode', () {
        test('page 1 is spread 0', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, 1, 10),
            0,
          );
        });

        test('page N is spread N-1', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, 5, 10),
            4,
          );
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, 10, 10),
            9,
          );
        });
      });

      group('booklet mode', () {
        test('pages 1-2 are spread 0', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.booklet, 1, 10),
            0,
          );
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.booklet, 2, 10),
            0,
          );
        });

        test('pages 3-4 are spread 1', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.booklet, 3, 10),
            1,
          );
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.booklet, 4, 10),
            1,
          );
        });

        test('pages 9-10 are spread 4', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.booklet, 9, 10),
            4,
          );
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.booklet, 10, 10),
            4,
          );
        });
      });

      group('continuousDouble mode', () {
        test('page 1 is spread 0', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(
              PdfViewMode.continuousDouble,
              1,
              10,
            ),
            0,
          );
        });

        test('page 5 is spread 4 (where it appears on left)', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(
              PdfViewMode.continuousDouble,
              5,
              10,
            ),
            4,
          );
        });

        test('last page returns last spread', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(
              PdfViewMode.continuousDouble,
              10,
              10,
            ),
            8,
          );
        });
      });

      group('edge cases', () {
        test('handles page 0', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, 0, 10),
            0,
          );
        });

        test('handles negative page', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, -1, 10),
            0,
          );
        });

        test('handles zero total pages', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, 1, 0),
            0,
          );
        });

        test('clamps page to total pages', () {
          expect(
            PageSpreadCalculator.getSpreadForPage(PdfViewMode.single, 100, 10),
            9,
          );
        });
      });
    });

    group('getPageSide', () {
      group('single mode', () {
        test('always returns left', () {
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.single, 1, 0),
            PageSide.left,
          );
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.single, 5, 4),
            PageSide.left,
          );
        });
      });

      group('booklet mode', () {
        test('odd pages are on left', () {
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.booklet, 1, 0),
            PageSide.left,
          );
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.booklet, 3, 1),
            PageSide.left,
          );
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.booklet, 5, 2),
            PageSide.left,
          );
        });

        test('even pages are on right', () {
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.booklet, 2, 0),
            PageSide.right,
          );
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.booklet, 4, 1),
            PageSide.right,
          );
          expect(
            PageSpreadCalculator.getPageSide(PdfViewMode.booklet, 6, 2),
            PageSide.right,
          );
        });
      });

      group('continuousDouble mode', () {
        test('first page of spread is left', () {
          expect(
            PageSpreadCalculator.getPageSide(
              PdfViewMode.continuousDouble,
              1,
              0,
            ),
            PageSide.left,
          );
          expect(
            PageSpreadCalculator.getPageSide(
              PdfViewMode.continuousDouble,
              3,
              2,
            ),
            PageSide.left,
          );
        });

        test('second page of spread is right', () {
          expect(
            PageSpreadCalculator.getPageSide(
              PdfViewMode.continuousDouble,
              2,
              0,
            ),
            PageSide.right,
          );
          expect(
            PageSpreadCalculator.getPageSide(
              PdfViewMode.continuousDouble,
              4,
              2,
            ),
            PageSide.right,
          );
        });
      });
    });

    group('integration tests', () {
      test('all spreads cover all pages in single mode', () {
        const totalPages = 10;
        final seenPages = <int>{};

        final totalSpreads = PageSpreadCalculator.getTotalSpreads(
          PdfViewMode.single,
          totalPages,
        );

        for (var i = 0; i < totalSpreads; i++) {
          final pages = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.single,
            i,
            totalPages,
          );
          seenPages.add(pages.leftPage);
          if (pages.rightPage != null) {
            seenPages.add(pages.rightPage!);
          }
        }

        expect(seenPages.length, totalPages);
        for (var i = 1; i <= totalPages; i++) {
          expect(seenPages.contains(i), isTrue);
        }
      });

      test('all spreads cover all pages in booklet mode', () {
        const totalPages = 10;
        final seenPages = <int>{};

        final totalSpreads = PageSpreadCalculator.getTotalSpreads(
          PdfViewMode.booklet,
          totalPages,
        );

        for (var i = 0; i < totalSpreads; i++) {
          final pages = PageSpreadCalculator.getPagesForSpread(
            PdfViewMode.booklet,
            i,
            totalPages,
          );
          seenPages.add(pages.leftPage);
          if (pages.rightPage != null) {
            seenPages.add(pages.rightPage!);
          }
        }

        expect(seenPages.length, totalPages);
        for (var i = 1; i <= totalPages; i++) {
          expect(seenPages.contains(i), isTrue);
        }
      });

      test('getSpreadForPage and getPagesForSpread are consistent', () {
        const totalPages = 10;

        for (final mode in PdfViewMode.values) {
          for (var page = 1; page <= totalPages; page++) {
            final spread = PageSpreadCalculator.getSpreadForPage(
              mode,
              page,
              totalPages,
            );
            final pages = PageSpreadCalculator.getPagesForSpread(
              mode,
              spread,
              totalPages,
            );

            // The page should be either left or right page of the spread
            expect(
              pages.leftPage == page || pages.rightPage == page,
              isTrue,
              reason: 'Page $page should be in spread $spread for mode $mode',
            );
          }
        }
      });
    });
  });
}
