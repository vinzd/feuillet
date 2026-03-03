# Set List Item Labels — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users assign custom labels to documents in set lists, displayed alongside the document name in both the detail screen and performance mode.

**Architecture:** Repurpose the existing `notes` column on `SetListItems` as the label field. Rename parameters throughout the service layer, add an update method, and wire labels into the detail screen (inline editable) and performance bottom controls (read-only display).

**Tech Stack:** Flutter, Drift (SQLite), Riverpod

---

### Task 1: Add `updateSetListItemLabel` to SetListService

**Files:**
- Modify: `lib/services/setlist_service.dart`
- Test: `test/services/setlist_service_test.dart`

**Step 1: Write the failing test**

Add to `test/services/setlist_service_test.dart`:

```dart
test('updateSetListItemLabel updates the label on a set list item', () async {
  final setListId = await setListService.createSetList('Concert');
  final doc = await createTestDocument('Sonate.pdf');
  final itemId = await setListService.addDocumentToSetList(
    setListId: setListId,
    documentId: doc.id,
  );

  await setListService.updateSetListItemLabel(itemId, 'Introduction');

  final items = await setListService.getSetListItems(setListId);
  expect(items.first.notes, 'Introduction');
});

test('updateSetListItemLabel clears label when set to null', () async {
  final setListId = await setListService.createSetList('Concert');
  final doc = await createTestDocument('Sonate.pdf');
  final itemId = await setListService.addDocumentToSetList(
    setListId: setListId,
    documentId: doc.id,
    notes: 'Old label',
  );

  await setListService.updateSetListItemLabel(itemId, null);

  final items = await setListService.getSetListItems(setListId);
  expect(items.first.notes, isNull);
});
```

Note: Check the existing test file for test helpers like `createTestDocument`. Adapt the helper name and setup to match what's already there.

**Step 2: Run tests to verify they fail**

Run: `flutter test test/services/setlist_service_test.dart`
Expected: FAIL — `updateSetListItemLabel` is not defined.

**Step 3: Implement `updateSetListItemLabel`**

In `lib/services/setlist_service.dart`, add this method to `SetListService`:

```dart
/// Update the label for a set list item
Future<void> updateSetListItemLabel(int itemId, String? label) async {
  await _database.updateSetListItemNotes(itemId, label);
}
```

This requires a database method. In `lib/models/database.dart`, add to `AppDatabase`:

```dart
Future<void> updateSetListItemNotes(int itemId, String? notes) async {
  await (update(setListItems)..where((t) => t.id.equals(itemId)))
      .write(SetListItemsCompanion(notes: Value(notes)));
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/services/setlist_service_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/setlist_service.dart lib/models/database.dart lib/models/database.g.dart test/services/setlist_service_test.dart
git commit -m "feat: add updateSetListItemLabel to SetListService"
```

---

### Task 2: Rename `notes` parameters to `label` in SetListService

**Files:**
- Modify: `lib/services/setlist_service.dart`
- Modify: `lib/screens/setlist_detail_screen.dart` (any callers passing `notes:`)
- Test: `test/services/setlist_service_test.dart`

**Step 1: Rename parameters**

In `lib/services/setlist_service.dart`, rename the `notes` parameter to `label` in `addDocumentToSetList`:

```dart
Future<int> addDocumentToSetList({
  required int setListId,
  required int documentId,
  String? label,
}) async {
  // ...
  final itemId = await _database.insertSetListItem(
    SetListItemsCompanion(
      setListId: drift.Value(setListId),
      documentId: drift.Value(documentId),
      orderIndex: drift.Value(orderIndex),
      notes: drift.Value(label),
    ),
  );
  // ...
}
```

In `duplicateSetList`, update the call:

```dart
await addDocumentToSetList(
  setListId: newSetListId,
  documentId: item.documentId,
  label: item.notes,
);
```

**Step 2: Update all callers**

Search for `notes:` in calls to `addDocumentToSetList` and rename to `label:`. Check `setlist_detail_screen.dart` and test files.

**Step 3: Run all tests**

Run: `flutter test`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/services/setlist_service.dart lib/screens/setlist_detail_screen.dart test/
git commit -m "refactor: rename notes parameter to label in SetListService"
```

---

### Task 3: Add inline label editing to SetListDetailScreen

**Files:**
- Modify: `lib/screens/setlist_detail_screen.dart`

**Step 1: Add label editing state**

Add to `_SetListDetailScreenState`:

```dart
int? _editingItemId;
late TextEditingController _labelController;

@override
void initState() {
  super.initState();
  _labelController = TextEditingController();
  _loadSetList();
}

@override
void dispose() {
  _labelController.dispose();
  super.dispose();
}
```

**Step 2: Add save method**

```dart
Future<void> _saveLabel(int itemId) async {
  final text = _labelController.text.trim();
  await _setListService.updateSetListItemLabel(
    itemId,
    text.isEmpty ? null : text,
  );
  await _setListService.touchSetList(widget.setListId);
  setState(() => _editingItemId = null);
  await _loadSetList();
}
```

**Step 3: Update the item builder in the `ReorderableListView`**

Replace the current `ListTile` subtitle and add label display/editing. The subtitle area should show:

- **When not editing:** The label text in italic style, or "Add label" placeholder in grey. Tapping enters edit mode.
- **When editing (`_editingItemId == item.id`):** An inline `TextField` that auto-focuses. Saves on submit (Enter) or focus loss.

```dart
subtitle: _editingItemId == item.id
    ? TextField(
        controller: _labelController,
        autofocus: true,
        style: const TextStyle(fontStyle: FontStyle.italic),
        decoration: const InputDecoration(
          hintText: 'Enter label...',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _saveLabel(item.id),
        onTapOutside: (_) => _saveLabel(item.id),
      )
    : GestureDetector(
        onTap: () {
          setState(() {
            _editingItemId = item.id;
            _labelController.text = item.notes ?? '';
          });
        },
        child: Text(
          item.notes ?? 'Add label',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: item.notes != null
                ? null
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
```

Remove the old `subtitle: Text('${doc.pageCount} pages')` line.

**Step 4: Run the app and verify**

Run: `make run-web` or `make run-macos`
Verify: Tap "Add label" shows inline text field. Type "Introduction", press Enter. Label persists after reload.

**Step 5: Commit**

```bash
git add lib/screens/setlist_detail_screen.dart
git commit -m "feat: add inline label editing to set list detail screen"
```

---

### Task 4: Show labels in performance mode bottom controls

**Files:**
- Modify: `lib/widgets/performance_bottom_controls.dart`
- Modify: `lib/screens/wrappers/setlist_performance_wrapper.dart`
- Modify: `lib/screens/setlist_performance_screen.dart`

**Step 1: Add `currentDocLabel` parameter to `PerformanceBottomControls`**

```dart
/// Optional label for the current document in this set list
final String? currentDocLabel;
```

Add it to the constructor with a default of `null`.

**Step 2: Display label beside document name**

In the `build` method, update the `currentDocName` Text widget area. When `currentDocLabel` is non-null, show "docName — label":

```dart
Text(
  currentDocLabel != null
      ? '$currentDocName — $currentDocLabel'
      : currentDocName,
  style: const TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  textAlign: TextAlign.center,
),
```

**Step 3: Pass items through the wrapper and performance screen**

In `setlist_performance_wrapper.dart`, update the provider to also fetch items:

```dart
final setListWithDocumentsProvider = FutureProvider.family<
    ({SetList? setList, List<Document> documents, List<SetListItem> items}),
    int>((ref, id) async {
  final setListService = SetListService();
  final setList = await setListService.getSetList(id);
  final documents = await setListService.getSetListDocuments(id);
  final items = await setListService.getSetListItems(id);
  return (setList: setList, documents: documents, items: items);
});
```

Pass `items` to `SetListPerformanceScreen`:

```dart
return SetListPerformanceScreen(
  setListId: setListId,
  documents: data.documents,
  items: data.items,
);
```

**Step 4: Add `items` parameter to `SetListPerformanceScreen`**

In `lib/screens/setlist_performance_screen.dart`:

```dart
class SetListPerformanceScreen extends StatefulWidget {
  final int setListId;
  final List<Document> documents;
  final List<SetListItem> items;

  const SetListPerformanceScreen({
    super.key,
    required this.setListId,
    required this.documents,
    required this.items,
  });
```

Then pass the label to the bottom controls:

```dart
PerformanceBottomControls(
  currentDocIndex: _currentDocIndex,
  totalDocs: widget.documents.length,
  currentDocName: widget.documents[_currentDocIndex].name,
  currentDocLabel: widget.items[_currentDocIndex].notes,
  // ... rest of existing params
),
```

**Step 5: Run the app and verify**

Run: `make run-web` or `make run-macos`
Verify: In performance mode, a document with label "Introduction" shows "Sonate.pdf — Introduction". A document without a label shows just the filename.

**Step 6: Commit**

```bash
git add lib/widgets/performance_bottom_controls.dart lib/screens/wrappers/setlist_performance_wrapper.dart lib/screens/setlist_performance_screen.dart
git commit -m "feat: show set list item labels in performance mode"
```

---

### Task 5: Run all tests and verify

**Step 1: Run full test suite**

Run: `make test`
Expected: All tests pass.

**Step 2: Run analyzer**

Run: `make analyze`
Expected: No issues.

**Step 3: Final commit if any fixes needed**

Fix any issues found and commit.
