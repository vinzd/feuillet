import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/l10n/app_localizations.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/utils/file_tree.dart';
import 'package:feuillet/widgets/file_tree_view.dart';

Document _document(int id, String name, String filePath) {
  return Document(
    id: id,
    name: name,
    filePath: filePath,
    dateAdded: DateTime(2024),
    lastOpened: null,
    lastModified: DateTime(2024),
    fileSize: 100,
    pageCount: 1,
    documentType: DocumentTypes.pdf,
  );
}

void main() {
  test('builds nested folders and keeps root files', () {
    final documents = [
      _document(1, 'Prelude', '/library/Bach/Prelude.pdf'),
      _document(2, 'Fugue', '/library/Bach/Fugue.pdf'),
      _document(3, 'Warmup', '/library/Warmup.pdf'),
    ];

    final roots = buildFileTree(documents);

    expect(roots.map((node) => node.name), ['Bach', 'Warmup']);
    expect(roots.first.isFolder, isTrue);
    expect(roots.first.children.map((node) => node.name), ['Fugue', 'Prelude']);
    expect(roots.last.document?.id, 3);
  });

  test('does not expose the shared absolute path prefix', () {
    final roots = buildFileTree([
      _document(1, 'First', '/Users/test/library/One/First.pdf'),
      _document(2, 'Second', '/Users/test/library/Two/Second.pdf'),
    ]);

    expect(roots.map((node) => node.name), ['One', 'Two']);
  });

  testWidgets('expands folders and forwards document taps', (tester) async {
    final document = _document(1, 'Prelude', '/library/Bach/Prelude.pdf');
    Document? tappedDocument;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FileTreeView(
            documents: [
              document,
              _document(2, 'Fugue', '/library/Bach/Fugue.pdf'),
              _document(3, 'Warmup', '/library/Warmup.pdf'),
            ],
            onDocumentTap: (value) => tappedDocument = value,
          ),
        ),
      ),
    );

    expect(find.text('Tree view'), findsNothing);
    expect(find.byKey(const ValueKey('folder-toggle-Bach')), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Prelude'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('folder-toggle-Bach')));
    await tester.pumpAndSettle();

    expect(find.text('Prelude'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tree-document-1')));
    expect(tappedDocument?.id, 1);
  });

  testWidgets('forwards long-presses for selection mode', (tester) async {
    final document = _document(1, 'Warmup', '/library/Warmup.pdf');
    Document? longPressedDocument;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FileTreeView(
            documents: [document],
            onDocumentTap: (_) {},
            onDocumentLongPress: (value) => longPressedDocument = value,
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('tree-document-1')));

    expect(longPressedDocument?.id, 1);
  });

  testWidgets('flattens expanded folders on a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FileTreeView(
            documents: [
              _document(1, 'Prelude', '/library/Bach/Prelude.pdf'),
              _document(2, 'Fugue', '/library/Bach/Fugue.pdf'),
              _document(3, 'Warmup', '/library/Warmup.pdf'),
            ],
            onDocumentTap: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('folder-toggle-Bach')));
    await tester.pumpAndSettle();
    expect(find.text('Prelude'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpAndSettle();
    expect(find.text('Prelude'), findsOneWidget);
    expect(find.text('Fugue'), findsOneWidget);
    expect(find.text('items'), findsNothing);

    final group = find.byKey(const ValueKey('compact-group-Bach'));
    expect(group, findsOneWidget);
    expect(
      tester.getSize(group).height,
      greaterThan(
        tester.getSize(find.byKey(const ValueKey('folder-toggle-Bach'))).height,
      ),
    );
  });
}
