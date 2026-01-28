import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_score/services/pdf_page_cache_service.dart';

void main() {
  group('PageCacheKey', () {
    test('equality works correctly', () {
      final key1 = PageCacheKey('doc1', 1);
      final key2 = PageCacheKey('doc1', 1);
      final key3 = PageCacheKey('doc1', 2);
      final key4 = PageCacheKey('doc2', 1);

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
      expect(key1, isNot(equals(key4)));
    });

    test('hashCode is consistent with equality', () {
      final key1 = PageCacheKey('doc1', 1);
      final key2 = PageCacheKey('doc1', 1);

      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('toString returns readable format', () {
      final key = PageCacheKey('doc1', 5);

      expect(key.toString(), contains('doc1'));
      expect(key.toString(), contains('5'));
    });

    test('can be used as Map key', () {
      final map = <PageCacheKey, String>{};
      final key1 = PageCacheKey('doc1', 1);
      final key2 = PageCacheKey('doc1', 1);

      map[key1] = 'value1';
      expect(map[key2], equals('value1'));
    });
  });

  group('CachedPageImage', () {
    test('stores bytes correctly', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final image = CachedPageImage(bytes: bytes, width: 100, height: 200);

      expect(image.bytes, equals(bytes));
      expect(image.width, equals(100));
      expect(image.height, equals(200));
    });

    test('sets cachedAt timestamp on creation', () {
      final before = DateTime.now();
      final image = CachedPageImage(
        bytes: Uint8List(0),
        width: 100,
        height: 200,
      );
      final after = DateTime.now();

      expect(
        image.cachedAt.isAfter(before) || image.cachedAt == before,
        isTrue,
      );
      expect(image.cachedAt.isBefore(after) || image.cachedAt == after, isTrue);
    });
  });

  group('PdfPageCacheService', () {
    late PdfPageCacheService service;

    setUp(() {
      // Get fresh instance and clear it
      service = PdfPageCacheService.instance;
      service.clearAll();
    });

    tearDown(() {
      service.clearAll();
    });

    test('singleton instance is consistent', () {
      final instance1 = PdfPageCacheService.instance;
      final instance2 = PdfPageCacheService.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    test('getCachedPage returns null for uncached page', () {
      final result = service.getCachedPage('doc1', 1);

      expect(result, isNull);
    });

    test('isPageCached returns false for uncached page', () {
      final result = service.isPageCached('doc1', 1);

      expect(result, isFalse);
    });

    test('cachePage stores and retrieves page correctly', () {
      final image = CachedPageImage(
        bytes: Uint8List.fromList([1, 2, 3]),
        width: 100,
        height: 200,
      );

      service.cachePage('doc1', 1, image);

      expect(service.isPageCached('doc1', 1), isTrue);
      expect(service.getCachedPage('doc1', 1), equals(image));
    });

    test('cachePage stores pages for different documents separately', () {
      final image1 = CachedPageImage(
        bytes: Uint8List.fromList([1]),
        width: 100,
        height: 200,
      );
      final image2 = CachedPageImage(
        bytes: Uint8List.fromList([2]),
        width: 100,
        height: 200,
      );

      service.cachePage('doc1', 1, image1);
      service.cachePage('doc2', 1, image2);

      expect(service.getCachedPage('doc1', 1)?.bytes, equals(image1.bytes));
      expect(service.getCachedPage('doc2', 1)?.bytes, equals(image2.bytes));
    });

    test('cachePage stores pages for different page numbers separately', () {
      final image1 = CachedPageImage(
        bytes: Uint8List.fromList([1]),
        width: 100,
        height: 200,
      );
      final image2 = CachedPageImage(
        bytes: Uint8List.fromList([2]),
        width: 100,
        height: 200,
      );

      service.cachePage('doc1', 1, image1);
      service.cachePage('doc1', 2, image2);

      expect(service.getCachedPage('doc1', 1)?.bytes, equals(image1.bytes));
      expect(service.getCachedPage('doc1', 2)?.bytes, equals(image2.bytes));
    });

    test('clearDocument removes only pages for that document', () {
      final image1 = CachedPageImage(
        bytes: Uint8List.fromList([1]),
        width: 100,
        height: 200,
      );
      final image2 = CachedPageImage(
        bytes: Uint8List.fromList([2]),
        width: 100,
        height: 200,
      );

      service.cachePage('doc1', 1, image1);
      service.cachePage('doc2', 1, image2);
      service.clearDocument('doc1');

      expect(service.isPageCached('doc1', 1), isFalse);
      expect(service.isPageCached('doc2', 1), isTrue);
    });

    test('clearAll removes all cached pages', () {
      final image = CachedPageImage(
        bytes: Uint8List.fromList([1]),
        width: 100,
        height: 200,
      );

      service.cachePage('doc1', 1, image);
      service.cachePage('doc2', 1, image);
      service.clearAll();

      expect(service.isPageCached('doc1', 1), isFalse);
      expect(service.isPageCached('doc2', 1), isFalse);
    });

    test('cache evicts oldest pages when exceeding maxPagesPerDocument', () {
      // maxPagesPerDocument is 25, so cache 27 pages
      for (int i = 1; i <= 27; i++) {
        final image = CachedPageImage(
          bytes: Uint8List.fromList([i]),
          width: 100,
          height: 200,
        );
        service.cachePage('doc1', i, image);
      }

      // Oldest pages (1, 2) should be evicted, newest should remain
      expect(service.isPageCached('doc1', 1), isFalse);
      expect(service.isPageCached('doc1', 2), isFalse);
      expect(service.isPageCached('doc1', 3), isTrue);
      expect(service.isPageCached('doc1', 27), isTrue);
    });

    test('cache eviction is per-document', () {
      // Fill doc1 cache
      for (int i = 1; i <= 27; i++) {
        final image = CachedPageImage(
          bytes: Uint8List.fromList([i]),
          width: 100,
          height: 200,
        );
        service.cachePage('doc1', i, image);
      }

      // Add page to doc2 - should not affect doc1 eviction
      final doc2Image = CachedPageImage(
        bytes: Uint8List.fromList([100]),
        width: 100,
        height: 200,
      );
      service.cachePage('doc2', 1, doc2Image);

      // doc2 page should exist
      expect(service.isPageCached('doc2', 1), isTrue);
      // doc1 still has its 25 most recent pages
      expect(service.isPageCached('doc1', 27), isTrue);
    });

    test('isPageRendering returns false initially', () {
      expect(service.isPageRendering('doc1', 1), isFalse);
    });

    test('preRenderRadius constant is accessible', () {
      expect(PdfPageCacheService.preRenderRadius, equals(10));
    });

    test('maxPagesPerDocument constant is accessible', () {
      expect(PdfPageCacheService.maxPagesPerDocument, equals(25));
    });
  });
}
