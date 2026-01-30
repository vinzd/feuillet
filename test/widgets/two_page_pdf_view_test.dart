import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/view_mode.dart';
import 'package:feuillet/widgets/two_page_pdf_view.dart';

/// TwoPagePdfView widget tests.
///
/// Full widget tests are limited due to dependencies on:
/// - PdfDocument from pdfx which requires actual PDF file loading
/// - CachedPdfPage which requires PDF rendering
///
/// Key behaviors verified through manual and integration testing:
/// - Row layout with two Expanded children for equal width
/// - Active page shows colored border, inactive shows transparent
/// - GestureDetector on each page calls onPageSideSelected
/// - Annotation overlay only created when selectedLayerId is not null
/// - Only active page is editable: isAnnotationMode && isActive && selectedLayerId != null
/// - Empty right side shows black container when rightPageNumber is null
/// - DrawingCanvas uses ValueKey('$selectedLayerId-$pageNumber') for proper
///   widget recreation when layer or page changes
void main() {
  group('TwoPagePdfView', () {
    test('widget is importable', () {
      expect(TwoPagePdfView, isNotNull);
    });
  });

  group('PageSide enum', () {
    test('has left and right values', () {
      expect(PageSide.values, containsAll([PageSide.left, PageSide.right]));
      expect(PageSide.values.length, 2);
    });
  });
}
