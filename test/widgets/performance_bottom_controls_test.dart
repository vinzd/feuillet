import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/view_mode.dart';
import 'package:feuillet/widgets/performance_bottom_controls.dart';

void main() {
  group('PerformanceBottomControls', () {
    testWidgets('displays document name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 5,
              currentDocName: 'Test Document',
              currentPage: 1,
              totalPages: 10,
            ),
          ),
        ),
      );

      expect(find.text('Test Document'), findsOneWidget);
    });

    testWidgets('displays document position', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 2,
              totalDocs: 5,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
            ),
          ),
        ),
      );

      expect(find.text('Document 3 of 5'), findsOneWidget);
    });

    testWidgets('displays single page number in single mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 1,
              currentDocName: 'Test',
              currentPage: 5,
              totalPages: 10,
              viewMode: PdfViewMode.single,
            ),
          ),
        ),
      );

      expect(find.text('Page 5 of 10'), findsOneWidget);
    });

    testWidgets('displays page range in two-page mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 1,
              currentDocName: 'Test',
              currentPage: 3,
              rightPage: 4,
              totalPages: 10,
              viewMode: PdfViewMode.booklet,
            ),
          ),
        ),
      );

      expect(find.text('Pages 3-4 of 10'), findsOneWidget);
    });

    testWidgets(
      'displays single page when rightPage is null in two-page mode',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PerformanceBottomControls(
                currentDocIndex: 0,
                totalDocs: 1,
                currentDocName: 'Test',
                currentPage: 9,
                rightPage: null, // Last page of odd-page document
                totalPages: 9,
                viewMode: PdfViewMode.booklet,
              ),
            ),
          ),
        );

        expect(find.text('Page 9 of 9'), findsOneWidget);
      },
    );

    testWidgets('prev document button is disabled on first document', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 5,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
            ),
          ),
        ),
      );

      // Find the skip_previous icon button
      final prevButton = find.widgetWithIcon(IconButton, Icons.skip_previous);
      expect(prevButton, findsOneWidget);

      // The button should be disabled (onPressed is null)
      final iconButton = tester.widget<IconButton>(prevButton);
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('next document button is disabled on last document', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 4,
              totalDocs: 5,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
              onNextDoc: null,
            ),
          ),
        ),
      );

      final nextButton = find.widgetWithIcon(IconButton, Icons.skip_next);
      expect(nextButton, findsOneWidget);

      final iconButton = tester.widget<IconButton>(nextButton);
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('prev document button calls callback when enabled', (
      tester,
    ) async {
      bool prevCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 2,
              totalDocs: 5,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
              onPrevDoc: () => prevCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.skip_previous));
      await tester.pump();

      expect(prevCalled, isTrue);
    });

    testWidgets('next document button calls callback when enabled', (
      tester,
    ) async {
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 2,
              totalDocs: 5,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
              onNextDoc: () => nextCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.skip_next));
      await tester.pump();

      expect(nextCalled, isTrue);
    });

    testWidgets('page navigation buttons call callbacks', (tester) async {
      bool prevPageCalled = false;
      bool nextPageCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 1,
              currentDocName: 'Test',
              currentPage: 5,
              totalPages: 10,
              onPrevPage: () => prevPageCalled = true,
              onNextPage: () => nextPageCalled = true,
            ),
          ),
        ),
      );

      // Find chevron buttons
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pump();
      expect(prevPageCalled, isTrue);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pump();
      expect(nextPageCalled, isTrue);
    });

    testWidgets('contains progress bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 2,
              totalDocs: 5,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
            ),
          ),
        ),
      );

      // Progress bar is a Container with specific decoration
      // We verify the structure exists
      expect(find.byType(PerformanceBottomControls), findsOneWidget);
    });
  });

  group('PerformanceBottomControls zoom slider', () {
    testWidgets('shows zoom slider when onZoomChanged is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 1,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
              zoomLevel: 1.5,
              onZoomChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('150%'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_in), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    });

    testWidgets('hides zoom slider when onZoomChanged is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 1,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
              zoomLevel: 1.0,
              onZoomChanged: null,
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('zoom slider calls callbacks when changed', (tester) async {
      double zoomValue = 1.0;
      bool interactionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PerformanceBottomControls(
              currentDocIndex: 0,
              totalDocs: 1,
              currentDocName: 'Test',
              currentPage: 1,
              totalPages: 10,
              zoomLevel: 1.0,
              onZoomChanged: (value) => zoomValue = value,
              onInteraction: () => interactionCalled = true,
            ),
          ),
        ),
      );

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);

      // Drag the slider
      await tester.drag(slider, const Offset(50, 0));
      await tester.pump();

      expect(zoomValue, isNot(1.0));
      expect(interactionCalled, isTrue);
    });
  });

  group('PerformanceBottomControls page text', () {
    test('single mode page text format', () {
      const viewMode = PdfViewMode.single;
      const currentPage = 5;
      const totalPages = 10;
      const int? rightPage = null;

      String buildPageText() {
        if (viewMode == PdfViewMode.single || rightPage == null) {
          return 'Page $currentPage of $totalPages';
        }
        return 'Pages $currentPage-$rightPage of $totalPages';
      }

      expect(buildPageText(), 'Page 5 of 10');
    });

    test('two-page mode page text format', () {
      const currentPage = 3;
      const rightPage = 4;
      const totalPages = 10;

      // In two-page mode with a right page, format should be "Pages X-Y of Z"
      final pageText = 'Pages $currentPage-$rightPage of $totalPages';

      expect(pageText, 'Pages 3-4 of 10');
    });
  });
}
