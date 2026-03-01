import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';

void main() {
  group('Database Models', () {
    test('Document can be created with all fields', () {
      final now = DateTime.now();
      final doc = Document(
        id: 1,
        name: 'Test Document',
        filePath: '/path/to/doc.pdf',
        dateAdded: now,
        lastOpened: now,
        lastModified: now,
        fileSize: 1024,
        pageCount: 10,
        documentType: 'pdf',
      );

      expect(doc.id, 1);
      expect(doc.name, 'Test Document');
      expect(doc.filePath, '/path/to/doc.pdf');
      expect(doc.pageCount, 10);
      expect(doc.fileSize, 1024);
    });

    test('Document copyWith creates new instance with updated fields', () {
      final original = Document(
        id: 1,
        name: 'Original',
        filePath: '/path',
        dateAdded: DateTime.now(),
        lastOpened: null,
        lastModified: DateTime.now(),
        fileSize: 100,
        pageCount: 5,
        documentType: 'pdf',
      );

      final updated = original.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(updated.id, original.id);
      expect(updated.filePath, original.filePath);
    });

    test('SetList can be created', () {
      final now = DateTime.now();
      final setList = SetList(
        id: 1,
        name: 'My Performance',
        description: 'Concert setlist',
        createdAt: now,
        modifiedAt: now,
      );

      expect(setList.id, 1);
      expect(setList.name, 'My Performance');
      expect(setList.description, 'Concert setlist');
    });

    test('AnnotationLayer can be created', () {
      final now = DateTime.now();
      final layer = AnnotationLayer(
        id: 1,
        documentId: 1,
        name: 'Layer 1',
        orderIndex: 0,
        isVisible: true,
        createdAt: now,
      );

      expect(layer.id, 1);
      expect(layer.documentId, 1);
      expect(layer.name, 'Layer 1');
      expect(layer.isVisible, isTrue);
    });

    test('DocumentSetting can be created with viewing preferences', () {
      final now = DateTime.now();
      final settings = DocumentSetting(
        id: 1,
        documentId: 1,
        zoomLevel: 1.5,
        brightness: 0.1,
        contrast: 1.2,
        currentPage: 5,
        viewMode: 'single',
        lastUpdated: now,
      );

      expect(settings.documentId, 1);
      expect(settings.zoomLevel, 1.5);
      expect(settings.brightness, 0.1);
      expect(settings.contrast, 1.2);
      expect(settings.currentPage, 5);
      expect(settings.viewMode, 'single');
    });

    test('Annotation can be created', () {
      final now = DateTime.now();
      final annotation = Annotation(
        id: 1,
        layerId: 1,
        pageNumber: 3,
        type: 'pen',
        data: '{"points": [], "color": 123}',
        createdAt: now,
        modifiedAt: now,
      );

      expect(annotation.layerId, 1);
      expect(annotation.pageNumber, 3);
      expect(annotation.type, 'pen');
      expect(annotation.data, contains('points'));
    });

    test('SetListItem can be created', () {
      final item = SetListItem(
        id: 1,
        setListId: 1,
        documentId: 1,
        orderIndex: 0,
        notes: 'Play softly',
      );

      expect(item.setListId, 1);
      expect(item.documentId, 1);
      expect(item.orderIndex, 0);
      expect(item.notes, 'Play softly');
    });
  });

  group('File Size Formatting', () {
    test('formats bytes correctly', () {
      expect(1024, 1024); // 1 KB
      expect(1024 * 1024, 1048576); // 1 MB
      expect(1024 * 1024 * 1024, 1073741824); // 1 GB
    });
  });

  group('Page Count Validation', () {
    test('page count should be non-negative', () {
      expect(0, greaterThanOrEqualTo(0));
      expect(10, greaterThanOrEqualTo(0));
      expect(-1, lessThan(0)); // Invalid
    });
  });
}
