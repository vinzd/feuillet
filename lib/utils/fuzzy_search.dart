import 'package:fuzzy/fuzzy.dart';
import '../models/database.dart';

/// Performs fuzzy search on a list of documents by name.
/// Returns all documents in original order when query is empty.
/// Blends fuzzy relevance score with recency (lastOpened) for ordering.
List<Document> fuzzySearchDocuments(
  List<Document> documents,
  String query, {
  DateTime? now,
}) {
  if (query.isEmpty) {
    return documents;
  }

  final fuse = Fuzzy<Document>(
    documents,
    options: FuzzyOptions(
      keys: [WeightedKey(name: 'name', getter: (doc) => doc.name, weight: 1.0)],
      threshold: 0.4,
      tokenize: true,
      shouldSort: true,
    ),
  );

  final results = fuse.search(query);

  // Blend fuzzy score with recency
  final referenceTime = now ?? DateTime.now();
  final scored = results.map((r) {
    final recencyPenalty = _recencyPenalty(r.item.lastOpened, referenceTime);
    final combinedScore = r.score * 0.8 + recencyPenalty * 0.2;
    return (doc: r.item, score: combinedScore);
  }).toList();

  scored.sort((a, b) => a.score.compareTo(b.score));

  return scored.map((s) => s.doc).toList();
}

/// Returns a penalty between 0.0 (recently opened) and 1.0 (never opened or old).
double _recencyPenalty(DateTime? lastOpened, DateTime now) {
  if (lastOpened == null) return 1.0;
  final daysSince = now.difference(lastOpened).inDays;
  // Normalize: 0 days = 0.0, 365+ days = 1.0
  return (daysSince / 365).clamp(0.0, 1.0);
}
