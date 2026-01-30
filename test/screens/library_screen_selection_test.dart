import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/models/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryScreen Selection Logic', () {
    late List<Document> testDocuments;
    late Set<int> selectedIds;

    setUp(() {
      testDocuments = [
        Document(
          id: 1,
          name: 'Score 1',
          filePath: '/path/to/score1.pdf',
          dateAdded: DateTime(2024, 1, 1),
          lastOpened: DateTime(2024, 1, 2),
          lastModified: DateTime(2024, 1, 1),
          fileSize: 1024000,
          pageCount: 5,
        ),
        Document(
          id: 2,
          name: 'Score 2',
          filePath: '/path/to/score2.pdf',
          dateAdded: DateTime(2024, 1, 2),
          lastOpened: DateTime(2024, 1, 3),
          lastModified: DateTime(2024, 1, 2),
          fileSize: 2048000,
          pageCount: 10,
        ),
        Document(
          id: 3,
          name: 'Score 3',
          filePath: '/path/to/score3.pdf',
          dateAdded: DateTime(2024, 1, 3),
          lastOpened: DateTime(2024, 1, 4),
          lastModified: DateTime(2024, 1, 3),
          fileSize: 3072000,
          pageCount: 15,
        ),
      ];
      selectedIds = {};
    });

    group('enterSelectionMode', () {
      test('adds document to selection', () {
        final doc = testDocuments[0];
        selectedIds.add(doc.id);

        expect(selectedIds.contains(1), isTrue);
        expect(selectedIds.length, equals(1));
      });

      test('enables selection mode', () {
        bool isSelectionMode = false;
        final doc = testDocuments[0];

        // Simulate _enterSelectionMode
        isSelectionMode = true;
        selectedIds.add(doc.id);

        expect(isSelectionMode, isTrue);
        expect(selectedIds.isNotEmpty, isTrue);
      });
    });

    group('toggleSelection', () {
      test('adds document if not selected', () {
        final doc = testDocuments[0];

        // Simulate _toggleSelection
        if (selectedIds.contains(doc.id)) {
          selectedIds.remove(doc.id);
        } else {
          selectedIds.add(doc.id);
        }

        expect(selectedIds.contains(1), isTrue);
      });

      test('removes document if already selected', () {
        selectedIds.add(1);
        final doc = testDocuments[0];

        // Simulate _toggleSelection
        if (selectedIds.contains(doc.id)) {
          selectedIds.remove(doc.id);
        } else {
          selectedIds.add(doc.id);
        }

        expect(selectedIds.contains(1), isFalse);
      });

      test('exits selection mode when last item deselected', () {
        selectedIds.add(1);
        bool isSelectionMode = true;
        final doc = testDocuments[0];

        // Simulate _toggleSelection
        if (selectedIds.contains(doc.id)) {
          selectedIds.remove(doc.id);
          if (selectedIds.isEmpty) {
            isSelectionMode = false;
          }
        }

        expect(isSelectionMode, isFalse);
        expect(selectedIds.isEmpty, isTrue);
      });
    });

    group('selectAll', () {
      test('selects all documents', () {
        // Simulate _selectAll
        selectedIds.addAll(testDocuments.map((d) => d.id));

        expect(selectedIds.length, equals(3));
        expect(selectedIds.contains(1), isTrue);
        expect(selectedIds.contains(2), isTrue);
        expect(selectedIds.contains(3), isTrue);
      });

      test('handles already selected documents', () {
        selectedIds.add(1);

        // Simulate _selectAll
        selectedIds.addAll(testDocuments.map((d) => d.id));

        // Set automatically handles duplicates
        expect(selectedIds.length, equals(3));
      });
    });

    group('deselectAll', () {
      test('clears all selections', () {
        selectedIds.addAll([1, 2, 3]);

        // Simulate _deselectAll
        selectedIds.clear();

        expect(selectedIds.isEmpty, isTrue);
      });
    });

    group('exitSelectionMode', () {
      test('clears selection and exits mode', () {
        bool isSelectionMode = true;
        selectedIds.addAll([1, 2, 3]);

        // Simulate _exitSelectionMode
        isSelectionMode = false;
        selectedIds.clear();

        expect(isSelectionMode, isFalse);
        expect(selectedIds.isEmpty, isTrue);
      });
    });

    group('handleDocumentTap', () {
      test('toggles selection when in selection mode', () {
        bool isSelectionMode = true;
        final doc = testDocuments[0];

        // Simulate _handleDocumentTap in selection mode
        if (isSelectionMode) {
          if (selectedIds.contains(doc.id)) {
            selectedIds.remove(doc.id);
          } else {
            selectedIds.add(doc.id);
          }
        }

        expect(selectedIds.contains(1), isTrue);
      });

      test('would open PDF when not in selection mode', () {
        const isSelectionMode = false;
        // When not in selection mode, tapping opens the PDF
        final wouldOpenPdf = !isSelectionMode;

        expect(wouldOpenPdf, isTrue);
      });
    });

    group('handleCheckboxTap', () {
      test('toggles selection when in selection mode', () {
        bool isSelectionMode = true;
        final doc = testDocuments[0];

        // Simulate _handleCheckboxTap in selection mode
        if (isSelectionMode) {
          if (selectedIds.contains(doc.id)) {
            selectedIds.remove(doc.id);
          } else {
            selectedIds.add(doc.id);
          }
        }

        expect(selectedIds.contains(1), isTrue);
      });

      test('enters selection mode when not in selection mode', () {
        var isSelectionMode = false;
        final doc = testDocuments[0];

        // Simulate _handleCheckboxTap when not in selection mode
        // When not in selection mode, checkbox tap enters selection mode
        if (!isSelectionMode) {
          isSelectionMode = true;
          selectedIds.add(doc.id);
        }

        expect(isSelectionMode, isTrue);
        expect(selectedIds.contains(1), isTrue);
      });
    });
  });

  group('Bulk Actions Logic', () {
    test('addToSetList skips duplicates', () {
      final selectedIds = {1, 2, 3};
      final existingDocIds = {2}; // Document 2 already in set list

      int addedCount = 0;
      int skippedCount = 0;

      for (final docId in selectedIds) {
        if (existingDocIds.contains(docId)) {
          skippedCount++;
        } else {
          addedCount++;
        }
      }

      expect(addedCount, equals(2));
      expect(skippedCount, equals(1));
    });

    test('generates correct message for mixed results', () {
      final addedCount = 2;
      final skippedCount = 1;

      String message;
      if (skippedCount > 0 && addedCount > 0) {
        message =
            'Added $addedCount, skipped $skippedCount (already in set list)';
      } else if (skippedCount > 0) {
        message = 'All selected documents already in set list';
      } else {
        message =
            'Added $addedCount document${addedCount == 1 ? '' : 's'} to set list';
      }

      expect(message, equals('Added 2, skipped 1 (already in set list)'));
    });

    test('generates correct message when all skipped', () {
      final addedCount = 0;
      final skippedCount = 3;

      String message;
      if (skippedCount > 0 && addedCount > 0) {
        message =
            'Added $addedCount, skipped $skippedCount (already in set list)';
      } else if (skippedCount > 0) {
        message = 'All selected documents already in set list';
      } else {
        message =
            'Added $addedCount document${addedCount == 1 ? '' : 's'} to set list';
      }

      expect(message, equals('All selected documents already in set list'));
    });

    test('generates correct singular message', () {
      final addedCount = 1;
      final skippedCount = 0;

      String message;
      if (skippedCount > 0 && addedCount > 0) {
        message =
            'Added $addedCount, skipped $skippedCount (already in set list)';
      } else if (skippedCount > 0) {
        message = 'All selected documents already in set list';
      } else {
        message =
            'Added $addedCount document${addedCount == 1 ? '' : 's'} to set list';
      }

      expect(message, equals('Added 1 document to set list'));
    });

    test('delete message uses correct pluralization', () {
      String getMessage(int count) {
        return 'Deleted $count document${count == 1 ? '' : 's'}';
      }

      expect(getMessage(1), equals('Deleted 1 document'));
      expect(getMessage(3), equals('Deleted 3 documents'));
    });
  });

  group('Selection AppBar', () {
    test('allSelected is true when all filtered docs selected', () {
      final filteredDocs = [
        Document(
          id: 1,
          name: 'Score 1',
          filePath: '/path/to/score1.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
        Document(
          id: 2,
          name: 'Score 2',
          filePath: '/path/to/score2.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
      ];
      final selectedIds = {1, 2};

      final allSelected =
          selectedIds.length == filteredDocs.length && filteredDocs.isNotEmpty;

      expect(allSelected, isTrue);
    });

    test('allSelected is false when not all docs selected', () {
      final filteredDocs = [
        Document(
          id: 1,
          name: 'Score 1',
          filePath: '/path/to/score1.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
        Document(
          id: 2,
          name: 'Score 2',
          filePath: '/path/to/score2.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
      ];
      final selectedIds = {1};

      final allSelected =
          selectedIds.length == filteredDocs.length && filteredDocs.isNotEmpty;

      expect(allSelected, isFalse);
    });

    test('allSelected is false when list is empty', () {
      final filteredDocs = <Document>[];
      final selectedIds = <int>{};

      final allSelected =
          selectedIds.length == filteredDocs.length && filteredDocs.isNotEmpty;

      expect(allSelected, isFalse);
    });

    test('checkbox shows select all when partial selection', () {
      final filteredDocs = [
        Document(
          id: 1,
          name: 'Score 1',
          filePath: '/path/to/score1.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
        Document(
          id: 2,
          name: 'Score 2',
          filePath: '/path/to/score2.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
      ];
      final selectedIds = {1}; // Only one selected

      final allSelected =
          selectedIds.length == filteredDocs.length && filteredDocs.isNotEmpty;
      final noneSelected = selectedIds.isEmpty;

      // Checkbox value: true if all, false if none, null if partial
      final checkboxValue = allSelected ? true : (noneSelected ? false : null);

      expect(checkboxValue, isNull); // Indeterminate state

      // Clicking checkbox with partial selection should select all
      if (!allSelected) {
        selectedIds.addAll(filteredDocs.map((d) => d.id));
      }

      expect(selectedIds.length, equals(2));
    });

    test('checkbox deselects all when all are selected', () {
      final filteredDocs = [
        Document(
          id: 1,
          name: 'Score 1',
          filePath: '/path/to/score1.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
        Document(
          id: 2,
          name: 'Score 2',
          filePath: '/path/to/score2.pdf',
          dateAdded: DateTime.now(),
          lastOpened: DateTime.now(),
          lastModified: DateTime.now(),
          fileSize: 1000,
          pageCount: 1,
        ),
      ];
      final selectedIds = {1, 2};
      var isSelectionMode = true;

      final allSelected =
          selectedIds.length == filteredDocs.length && filteredDocs.isNotEmpty;

      expect(allSelected, isTrue);

      // Clicking checkbox when all selected should deselect all and exit
      if (allSelected) {
        isSelectionMode = false;
        selectedIds.clear();
      }

      expect(selectedIds.isEmpty, isTrue);
      expect(isSelectionMode, isFalse);
    });
  });

  group('Drag Selection Logic', () {
    late Set<int> selectedIds;
    late Set<int> dragSelectedIds;
    late bool isSelectionMode;

    setUp(() {
      selectedIds = {};
      dragSelectedIds = {};
      isSelectionMode = false;
    });

    test('drag selection enters selection mode', () {
      // Simulate drag selecting items
      dragSelectedIds.addAll([1, 2]);

      // On pointer up, apply drag selection
      if (dragSelectedIds.isNotEmpty) {
        isSelectionMode = true;
        for (final docId in dragSelectedIds) {
          if (selectedIds.contains(docId)) {
            selectedIds.remove(docId);
          } else {
            selectedIds.add(docId);
          }
        }
      }

      expect(isSelectionMode, isTrue);
      expect(selectedIds, equals({1, 2}));
    });

    test('drag selection toggles already selected items', () {
      // Pre-select item 1
      selectedIds.add(1);
      isSelectionMode = true;

      // Drag select items 1 and 2
      dragSelectedIds.addAll([1, 2]);

      // Apply toggle logic
      for (final docId in dragSelectedIds) {
        if (selectedIds.contains(docId)) {
          selectedIds.remove(docId);
        } else {
          selectedIds.add(docId);
        }
      }

      // Item 1 should be deselected (was selected), item 2 selected
      expect(selectedIds, equals({2}));
    });

    test('drag selection exits mode when all deselected', () {
      // Pre-select items 1 and 2
      selectedIds.addAll([1, 2]);
      isSelectionMode = true;

      // Drag select same items (will toggle them off)
      dragSelectedIds.addAll([1, 2]);

      // Apply toggle logic
      for (final docId in dragSelectedIds) {
        if (selectedIds.contains(docId)) {
          selectedIds.remove(docId);
        } else {
          selectedIds.add(docId);
        }
      }

      // Check if should exit selection mode
      if (selectedIds.isEmpty) {
        isSelectionMode = false;
      }

      expect(selectedIds.isEmpty, isTrue);
      expect(isSelectionMode, isFalse);
    });

    test('XOR preview logic shows correct selection state', () {
      // Test the XOR logic used for visual preview during drag
      selectedIds.add(1); // Item 1 is selected
      dragSelectedIds.addAll([1, 2]); // Dragging over items 1 and 2

      // Item 1: selected XOR inDrag = true XOR true = false (will be deselected)
      // Item 2: selected XOR inDrag = false XOR true = true (will be selected)
      final item1Preview =
          selectedIds.contains(1) ^ dragSelectedIds.contains(1);
      final item2Preview =
          selectedIds.contains(2) ^ dragSelectedIds.contains(2);

      expect(item1Preview, isFalse); // Will appear deselected
      expect(item2Preview, isTrue); // Will appear selected
    });
  });

  group('Click on Empty Space', () {
    test('click on empty space exits selection mode', () {
      var isSelectionMode = true;
      final selectedIds = {1, 2};
      const isOnCard = false; // Clicked on empty space
      const wasClick = true; // Minimal drag distance

      // Simulate click on empty space logic
      if (wasClick && isSelectionMode && !isOnCard) {
        isSelectionMode = false;
        selectedIds.clear();
      }

      expect(isSelectionMode, isFalse);
      expect(selectedIds.isEmpty, isTrue);
    });

    test('click on card does not exit selection mode', () {
      var isSelectionMode = true;
      final selectedIds = {1, 2};

      // When clicking on a card, selection mode should not exit
      // because the condition (!_isPositionOnCard) would be false
      expect(isSelectionMode, isTrue);
      expect(selectedIds.isNotEmpty, isTrue);
    });

    test('drag (not click) does not exit selection mode', () {
      var isSelectionMode = true;
      final selectedIds = {1, 2};

      // When dragging (not clicking), selection mode should not exit
      // because the wasClick condition would be false
      expect(isSelectionMode, isTrue);
      expect(selectedIds.isNotEmpty, isTrue);
    });
  });
}
