import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';
import 'package:feuillet/screens/library_screen.dart';

/// Replicates the _filterDocuments sorting logic from LibraryScreen
List<Document> sortDocuments(
  List<Document> documents, {
  required LibrarySortField sortField,
  required bool sortAscending,
  String searchQuery = '',
}) {
  var result = documents;
  if (searchQuery.isNotEmpty) {
    result = result.where((doc) {
      return doc.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }
  result = List.of(result);
  switch (sortField) {
    case LibrarySortField.name:
      result.sort(
        (a, b) => sortAscending
            ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
            : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      );
    case LibrarySortField.dateAdded:
      result.sort(
        (a, b) => sortAscending
            ? a.dateAdded.compareTo(b.dateAdded)
            : b.dateAdded.compareTo(a.dateAdded),
      );
    case LibrarySortField.fileSize:
      result.sort(
        (a, b) => sortAscending
            ? a.fileSize.compareTo(b.fileSize)
            : b.fileSize.compareTo(a.fileSize),
      );
    case LibrarySortField.pageCount:
      result.sort(
        (a, b) => sortAscending
            ? a.pageCount.compareTo(b.pageCount)
            : b.pageCount.compareTo(a.pageCount),
      );
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Document> testDocuments;

  setUp(() {
    testDocuments = [
      Document(
        id: 1,
        name: 'Beethoven Sonata',
        filePath: '/path/to/beethoven.pdf',
        dateAdded: DateTime(2024, 3, 15),
        lastOpened: DateTime(2024, 3, 16),
        lastModified: DateTime(2024, 3, 15),
        fileSize: 1024000,
        pageCount: 10,
        documentType: 'pdf',
      ),
      Document(
        id: 2,
        name: 'Mozart Concerto',
        filePath: '/path/to/mozart.pdf',
        dateAdded: DateTime(2024, 1, 10),
        lastOpened: DateTime(2024, 1, 11),
        lastModified: DateTime(2024, 1, 10),
        fileSize: 2048000,
        pageCount: 20,
        documentType: 'pdf',
      ),
      Document(
        id: 3,
        name: 'Bach Fugue',
        filePath: '/path/to/bach.pdf',
        dateAdded: DateTime(2024, 6, 1),
        lastOpened: DateTime(2024, 6, 2),
        lastModified: DateTime(2024, 6, 1),
        fileSize: 512000,
        pageCount: 5,
        documentType: 'pdf',
      ),
    ];
  });

  group('Library Sort - by name', () {
    test('ascending sorts A to Z', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.name,
        sortAscending: true,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Bach Fugue',
        'Beethoven Sonata',
        'Mozart Concerto',
      ]);
    });

    test('descending sorts Z to A', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.name,
        sortAscending: false,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Mozart Concerto',
        'Beethoven Sonata',
        'Bach Fugue',
      ]);
    });

    test('name sort is case-insensitive', () {
      final docs = [
        Document(
          id: 1,
          name: 'zebra',
          filePath: '/z.pdf',
          dateAdded: DateTime(2024, 1, 1),
          lastOpened: DateTime(2024, 1, 1),
          lastModified: DateTime(2024, 1, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
        Document(
          id: 2,
          name: 'Alpha',
          filePath: '/a.pdf',
          dateAdded: DateTime(2024, 1, 1),
          lastOpened: DateTime(2024, 1, 1),
          lastModified: DateTime(2024, 1, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
      ];

      final sorted = sortDocuments(
        docs,
        sortField: LibrarySortField.name,
        sortAscending: true,
      );

      expect(sorted.map((d) => d.name).toList(), ['Alpha', 'zebra']);
    });
  });

  group('Library Sort - by date added', () {
    test('ascending sorts oldest first', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.dateAdded,
        sortAscending: true,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Mozart Concerto', // Jan 10
        'Beethoven Sonata', // Mar 15
        'Bach Fugue', // Jun 1
      ]);
    });

    test('descending sorts newest first', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.dateAdded,
        sortAscending: false,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Bach Fugue', // Jun 1
        'Beethoven Sonata', // Mar 15
        'Mozart Concerto', // Jan 10
      ]);
    });
  });

  group('Library Sort - by file size', () {
    test('ascending sorts smallest first', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.fileSize,
        sortAscending: true,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Bach Fugue', // 512000
        'Beethoven Sonata', // 1024000
        'Mozart Concerto', // 2048000
      ]);
    });

    test('descending sorts largest first', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.fileSize,
        sortAscending: false,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Mozart Concerto', // 2048000
        'Beethoven Sonata', // 1024000
        'Bach Fugue', // 512000
      ]);
    });
  });

  group('Library Sort - by page count', () {
    test('ascending sorts fewest pages first', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.pageCount,
        sortAscending: true,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Bach Fugue', // 5
        'Beethoven Sonata', // 10
        'Mozart Concerto', // 20
      ]);
    });

    test('descending sorts most pages first', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.pageCount,
        sortAscending: false,
      );

      expect(sorted.map((d) => d.name).toList(), [
        'Mozart Concerto', // 20
        'Beethoven Sonata', // 10
        'Bach Fugue', // 5
      ]);
    });
  });

  group('Library Sort - with search filter', () {
    test('filters then sorts by name ascending', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.name,
        sortAscending: true,
        searchQuery: 'b',
      );

      // Only Beethoven and Bach match 'b'
      expect(sorted.map((d) => d.name).toList(), [
        'Bach Fugue',
        'Beethoven Sonata',
      ]);
    });

    test('returns empty when no matches', () {
      final sorted = sortDocuments(
        testDocuments,
        sortField: LibrarySortField.name,
        sortAscending: true,
        searchQuery: 'xyz',
      );

      expect(sorted, isEmpty);
    });
  });

  group('Library Sort - does not mutate input', () {
    test('original list is not modified', () {
      final originalNames = testDocuments.map((d) => d.name).toList();

      sortDocuments(
        testDocuments,
        sortField: LibrarySortField.name,
        sortAscending: true,
      );

      expect(testDocuments.map((d) => d.name).toList(), originalNames);
    });
  });

  group('Library Sort - toggle direction behavior', () {
    test('tapping same field toggles direction', () {
      var sortField = LibrarySortField.dateAdded;
      var sortAscending = false;

      // Simulate tapping the same field
      final tappedField = LibrarySortField.dateAdded;
      if (sortField == tappedField) {
        sortAscending = !sortAscending;
      }

      expect(sortAscending, isTrue);
    });

    test('switching field sets sensible default direction', () {
      var sortField = LibrarySortField.dateAdded;
      var sortAscending = false;

      // Simulate switching to name
      final tappedField = LibrarySortField.name;
      if (sortField == tappedField) {
        sortAscending = !sortAscending;
      } else {
        sortField = tappedField;
        sortAscending = tappedField == LibrarySortField.name;
      }

      expect(sortField, LibrarySortField.name);
      expect(sortAscending, isTrue); // A-Z by default for name
    });

    test('switching to file size sets largest first by default', () {
      var sortField = LibrarySortField.name;
      var sortAscending = true;

      final tappedField = LibrarySortField.fileSize;
      if (sortField == tappedField) {
        sortAscending = !sortAscending;
      } else {
        sortField = tappedField;
        sortAscending = tappedField == LibrarySortField.name;
      }

      expect(sortField, LibrarySortField.fileSize);
      expect(sortAscending, isFalse); // largest first by default
    });

    test('switching to page count sets most pages first by default', () {
      var sortField = LibrarySortField.name;
      var sortAscending = true;

      final tappedField = LibrarySortField.pageCount;
      if (sortField == tappedField) {
        sortAscending = !sortAscending;
      } else {
        sortField = tappedField;
        sortAscending = tappedField == LibrarySortField.name;
      }

      expect(sortField, LibrarySortField.pageCount);
      expect(sortAscending, isFalse); // most pages first by default
    });

    test('switching to date sets newest first by default', () {
      var sortField = LibrarySortField.name;
      var sortAscending = true;

      // Simulate switching to date
      final tappedField = LibrarySortField.dateAdded;
      if (sortField == tappedField) {
        sortAscending = !sortAscending;
      } else {
        sortField = tappedField;
        sortAscending = tappedField == LibrarySortField.name;
      }

      expect(sortField, LibrarySortField.dateAdded);
      expect(sortAscending, isFalse); // newest first by default for date
    });
  });

  group('Set list document picker - sort by name', () {
    test('available documents are sorted alphabetically', () {
      final allDocuments = [
        Document(
          id: 1,
          name: 'Waltz in C',
          filePath: '/w.pdf',
          dateAdded: DateTime(2024, 1, 1),
          lastOpened: DateTime(2024, 1, 1),
          lastModified: DateTime(2024, 1, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
        Document(
          id: 2,
          name: 'Etude No. 3',
          filePath: '/e.pdf',
          dateAdded: DateTime(2024, 2, 1),
          lastOpened: DateTime(2024, 2, 1),
          lastModified: DateTime(2024, 2, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
        Document(
          id: 3,
          name: 'Aria in G',
          filePath: '/a.pdf',
          dateAdded: DateTime(2024, 3, 1),
          lastOpened: DateTime(2024, 3, 1),
          lastModified: DateTime(2024, 3, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
      ];

      final currentDocIds = <int>{}; // No docs in set list yet

      // Replicate the logic from setlist_detail_screen.dart _addDocuments
      final availableDocs =
          allDocuments.where((d) => !currentDocIds.contains(d.id)).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      expect(availableDocs.map((d) => d.name).toList(), [
        'Aria in G',
        'Etude No. 3',
        'Waltz in C',
      ]);
    });

    test('excludes documents already in set list', () {
      final allDocuments = [
        Document(
          id: 1,
          name: 'Waltz in C',
          filePath: '/w.pdf',
          dateAdded: DateTime(2024, 1, 1),
          lastOpened: DateTime(2024, 1, 1),
          lastModified: DateTime(2024, 1, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
        Document(
          id: 2,
          name: 'Etude No. 3',
          filePath: '/e.pdf',
          dateAdded: DateTime(2024, 2, 1),
          lastOpened: DateTime(2024, 2, 1),
          lastModified: DateTime(2024, 2, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
        Document(
          id: 3,
          name: 'Aria in G',
          filePath: '/a.pdf',
          dateAdded: DateTime(2024, 3, 1),
          lastOpened: DateTime(2024, 3, 1),
          lastModified: DateTime(2024, 3, 1),
          fileSize: 100,
          pageCount: 1,
          documentType: 'pdf',
        ),
      ];

      final currentDocIds = {2}; // Etude already in set list

      final availableDocs =
          allDocuments.where((d) => !currentDocIds.contains(d.id)).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      expect(availableDocs.map((d) => d.name).toList(), [
        'Aria in G',
        'Waltz in C',
      ]);
    });
  });
}
