import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Query Operations', () {
    test('sorting by date', () {
      final dates = [
        DateTime(2024, 1, 3),
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 2),
      ];

      dates.sort((a, b) => b.compareTo(a)); // Sort descending

      expect(dates[0], DateTime(2024, 1, 3));
      expect(dates[1], DateTime(2024, 1, 2));
      expect(dates[2], DateTime(2024, 1, 1));
    });

    test('sorting by name', () {
      final names = ['Zebra', 'Apple', 'Mango'];

      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      expect(names, ['Apple', 'Mango', 'Zebra']);
    });

    test('filtering by search term', () {
      final documents = [
        {'name': 'Beethoven Symphony No. 5'},
        {'name': 'Mozart Requiem'},
        {'name': 'Beethoven Piano Sonata'},
      ];

      final searchTerm = 'beethoven';
      final filtered = documents.where((doc) =>
        (doc['name'] as String).toLowerCase().contains(searchTerm)
      ).toList();

      expect(filtered.length, 2);
      expect(filtered[0]['name'], contains('Beethoven'));
    });

    test('pagination', () {
      final items = List.generate(100, (i) => 'Item $i');
      final pageSize = 20;
      final page = 2;

      final start = (page - 1) * pageSize;
      final end = start + pageSize;
      final pageItems = items.sublist(start, end.clamp(0, items.length));

      expect(pageItems.length, 20);
      expect(pageItems.first, 'Item 20');
      expect(pageItems.last, 'Item 39');
    });

    test('distinct values', () {
      final tags = ['classical', 'jazz', 'classical', 'rock', 'jazz'];
      final distinctTags = tags.toSet().toList();

      expect(distinctTags.length, 3);
      expect(distinctTags.contains('classical'), isTrue);
      expect(distinctTags.contains('jazz'), isTrue);
      expect(distinctTags.contains('rock'), isTrue);
    });
  });

  group('Document Statistics', () {
    test('total page count', () {
      final documents = [
        {'pageCount': 10},
        {'pageCount': 20},
        {'pageCount': 15},
      ];

      final totalPages = documents.fold<int>(
        0,
        (sum, doc) => sum + (doc['pageCount'] as int)
      );

      expect(totalPages, 45);
    });

    test('average file size', () {
      final fileSizes = [1024, 2048, 3072]; // in bytes

      final average = fileSizes.reduce((a, b) => a + b) / fileSizes.length;

      expect(average, 2048);
    });

    test('most recently added', () {
      final documents = [
        {'name': 'Doc1', 'dateAdded': DateTime(2024, 1, 1)},
        {'name': 'Doc2', 'dateAdded': DateTime(2024, 1, 3)},
        {'name': 'Doc3', 'dateAdded': DateTime(2024, 1, 2)},
      ];

      documents.sort((a, b) =>
        (b['dateAdded'] as DateTime).compareTo(a['dateAdded'] as DateTime)
      );

      expect(documents[0]['name'], 'Doc2');
    });

    test('most frequently opened', () {
      final documents = [
        {'name': 'Doc1', 'openCount': 5},
        {'name': 'Doc2', 'openCount': 15},
        {'name': 'Doc3', 'openCount': 10},
      ];

      documents.sort((a, b) =>
        (b['openCount'] as int).compareTo(a['openCount'] as int)
      );

      expect(documents[0]['name'], 'Doc2');
      expect(documents[0]['openCount'], 15);
    });
  });

  group('SetList Queries', () {
    test('get documents in setlist', () {
      final setlistItems = [
        {'documentId': 1, 'order': 0},
        {'documentId': 3, 'order': 1},
        {'documentId': 2, 'order': 2},
      ];

      // Sort by order
      setlistItems.sort((a, b) =>
        (a['order'] as int).compareTo(b['order'] as int)
      );

      expect(setlistItems[0]['documentId'], 1);
      expect(setlistItems[1]['documentId'], 3);
      expect(setlistItems[2]['documentId'], 2);
    });

    test('find setlists containing document', () {
      final setlists = [
        {'id': 1, 'name': 'Concert A', 'documentIds': [1, 2, 3]},
        {'id': 2, 'name': 'Concert B', 'documentIds': [2, 4, 5]},
        {'id': 3, 'name': 'Concert C', 'documentIds': [6, 7, 8]},
      ];

      final documentId = 2;
      final containing = setlists.where((setlist) =>
        (setlist['documentIds'] as List<int>).contains(documentId)
      ).toList();

      expect(containing.length, 2);
      expect(containing[0]['name'], 'Concert A');
      expect(containing[1]['name'], 'Concert B');
    });

    test('setlist item count', () {
      final setlist = {
        'id': 1,
        'name': 'My Setlist',
        'items': [1, 2, 3, 4, 5],
      };

      expect((setlist['items'] as List).length, 5);
    });
  });

  group('Annotation Queries', () {
    test('get annotations for page', () {
      final annotations = [
        {'pageNumber': 0, 'type': 'pen'},
        {'pageNumber': 1, 'type': 'highlighter'},
        {'pageNumber': 0, 'type': 'text'},
        {'pageNumber': 2, 'type': 'pen'},
      ];

      final pageNumber = 0;
      final pageAnnotations = annotations.where((a) =>
        a['pageNumber'] == pageNumber
      ).toList();

      expect(pageAnnotations.length, 2);
    });

    test('get annotations by layer', () {
      final annotations = [
        {'layerId': 1, 'type': 'pen'},
        {'layerId': 2, 'type': 'highlighter'},
        {'layerId': 1, 'type': 'text'},
      ];

      final layerId = 1;
      final layerAnnotations = annotations.where((a) =>
        a['layerId'] == layerId
      ).toList();

      expect(layerAnnotations.length, 2);
    });

    test('count annotations by type', () {
      final annotations = [
        {'type': 'pen'},
        {'type': 'highlighter'},
        {'type': 'pen'},
        {'type': 'pen'},
        {'type': 'text'},
      ];

      final penCount = annotations.where((a) => a['type'] == 'pen').length;

      expect(penCount, 3);
    });
  });
}
