import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/view_mode.dart';

void main() {
  group('PdfViewMode', () {
    test('has three view modes', () {
      expect(PdfViewMode.values.length, 3);
      expect(PdfViewMode.values, contains(PdfViewMode.single));
      expect(PdfViewMode.values, contains(PdfViewMode.booklet));
      expect(PdfViewMode.values, contains(PdfViewMode.continuousDouble));
    });

    group('displayName', () {
      test('single returns "Single Page"', () {
        expect(PdfViewMode.single.displayName, 'Single Page');
      });

      test('booklet returns "Booklet"', () {
        expect(PdfViewMode.booklet.displayName, 'Booklet');
      });

      test('continuousDouble returns "Continuous Double"', () {
        expect(PdfViewMode.continuousDouble.displayName, 'Continuous Double');
      });
    });

    group('icon', () {
      test('single returns Icons.article', () {
        expect(PdfViewMode.single.icon, Icons.article);
      });

      test('booklet returns Icons.menu_book', () {
        expect(PdfViewMode.booklet.icon, Icons.menu_book);
      });

      test('continuousDouble returns Icons.auto_stories', () {
        expect(PdfViewMode.continuousDouble.icon, Icons.auto_stories);
      });
    });

    group('toStorageString', () {
      test('single returns "single"', () {
        expect(PdfViewMode.single.toStorageString(), 'single');
      });

      test('booklet returns "booklet"', () {
        expect(PdfViewMode.booklet.toStorageString(), 'booklet');
      });

      test('continuousDouble returns "continuousDouble"', () {
        expect(
          PdfViewMode.continuousDouble.toStorageString(),
          'continuousDouble',
        );
      });
    });

    group('fromStorageString', () {
      test('parses "single" correctly', () {
        expect(PdfViewMode.fromStorageString('single'), PdfViewMode.single);
      });

      test('parses "booklet" correctly', () {
        expect(PdfViewMode.fromStorageString('booklet'), PdfViewMode.booklet);
      });

      test('parses "continuousDouble" correctly', () {
        expect(
          PdfViewMode.fromStorageString('continuousDouble'),
          PdfViewMode.continuousDouble,
        );
      });

      test('returns single for invalid input', () {
        expect(PdfViewMode.fromStorageString('invalid'), PdfViewMode.single);
        expect(PdfViewMode.fromStorageString(''), PdfViewMode.single);
        expect(PdfViewMode.fromStorageString('SINGLE'), PdfViewMode.single);
      });
    });

    group('isTwoPage', () {
      test('single is not two-page', () {
        expect(PdfViewMode.single.isTwoPage, isFalse);
      });

      test('booklet is two-page', () {
        expect(PdfViewMode.booklet.isTwoPage, isTrue);
      });

      test('continuousDouble is two-page', () {
        expect(PdfViewMode.continuousDouble.isTwoPage, isTrue);
      });
    });

    group('roundtrip serialization', () {
      test('all modes survive roundtrip', () {
        for (final mode in PdfViewMode.values) {
          final stored = mode.toStorageString();
          final restored = PdfViewMode.fromStorageString(stored);
          expect(restored, mode);
        }
      });
    });
  });

  group('PageSide', () {
    test('has two sides', () {
      expect(PageSide.values.length, 2);
      expect(PageSide.values, contains(PageSide.left));
      expect(PageSide.values, contains(PageSide.right));
    });

    test('left and right are distinct', () {
      expect(PageSide.left, isNot(PageSide.right));
    });
  });
}
