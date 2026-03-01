import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/utils/fuzzy_search.dart';
import 'package:feuillet/models/database.dart';

Document _makeDoc(int id, String name, {DateTime? lastOpened}) {
  return Document(
    id: id,
    name: name,
    filePath: '/path/$name.pdf',
    dateAdded: DateTime(2024, 1, 1),
    lastOpened: lastOpened,
    lastModified: DateTime(2024, 1, 1),
    fileSize: 1000,
    pageCount: 10,
    documentType: 'pdf',
  );
}

void main() {
  group('fuzzySearchDocuments', () {
    final docs = [
      _makeDoc(1, 'Bach - Cello Suite No. 1', lastOpened: DateTime(2024, 6, 1)),
      _makeDoc(
        2,
        'Beethoven - Moonlight Sonata',
        lastOpened: DateTime(2024, 1, 1),
      ),
      _makeDoc(3, 'Mozart - Eine Kleine Nachtmusik'),
      _makeDoc(4, 'Debussy - Clair de Lune', lastOpened: DateTime(2024, 12, 1)),
    ];

    test('empty query returns all documents in original order', () {
      final result = fuzzySearchDocuments(docs, '');
      expect(result.map((d) => d.id).toList(), [1, 2, 3, 4]);
    });

    test('exact substring match returns document', () {
      final result = fuzzySearchDocuments(docs, 'Bach');
      expect(result.any((d) => d.name.contains('Bach')), isTrue);
    });

    test('skipped letters match (subsequence)', () {
      // "bch" should match "Bach"
      final result = fuzzySearchDocuments(docs, 'bch');
      expect(result.any((d) => d.name.contains('Bach')), isTrue);
    });

    test('misspelling match (edit distance)', () {
      // "Bethovn" should match "Beethoven"
      final result = fuzzySearchDocuments(docs, 'Bethovn');
      expect(result.any((d) => d.name.contains('Beethoven')), isTrue);
    });

    test('no match returns empty list', () {
      final result = fuzzySearchDocuments(docs, 'xyzxyzxyz');
      expect(result, isEmpty);
    });

    test('results are sorted by relevance', () {
      // Exact match should rank higher than fuzzy match
      final result = fuzzySearchDocuments(docs, 'Bach');
      expect(result.length, greaterThanOrEqualTo(1));
      expect(result.first.name.contains('Bach'), isTrue);
    });

    test('recently opened docs rank higher among similar scores', () {
      // Debussy (lastOpened: Dec 2024) should get a recency boost over others
      // Use a controlled "now" so recency differences are meaningful
      final result = fuzzySearchDocuments(
        docs,
        'Clair',
        now: DateTime(2024, 12, 15),
      );
      expect(result, isNotEmpty);
      expect(result.first.name.contains('Debussy'), isTrue);
    });
  });
}
