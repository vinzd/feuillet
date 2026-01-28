import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/models/database.dart';
import 'package:open_score/widgets/pdf_card.dart';

void main() {
  group('PdfCard Widget', () {
    late Document testDocument;

    setUp(() {
      testDocument = Document(
        id: 1,
        name: 'Test Score',
        filePath: '/path/to/test.pdf',
        dateAdded: DateTime(2024, 1, 1),
        lastOpened: DateTime(2024, 1, 2),
        lastModified: DateTime(2024, 1, 1),
        fileSize: 1024000, // 1MB
        pageCount: 5,
      );
    });

    testWidgets('displays document name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCard(
              document: testDocument,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Score'), findsOneWidget);
    });

    testWidgets('displays page count', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCard(
              document: testDocument,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('5'), findsAtLeast(1));
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfCard(
              document: testDocument,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PdfCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('renders with different page counts',
        (WidgetTester tester) async {
      final documents = [
        testDocument.copyWith(pageCount: 1),
        testDocument.copyWith(pageCount: 10),
        testDocument.copyWith(pageCount: 100),
      ];

      for (final doc in documents) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PdfCard(
                document: doc,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.byType(PdfCard), findsOneWidget);
      }
    });
  });
}
