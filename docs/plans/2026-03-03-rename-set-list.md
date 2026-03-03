# Rename Set List Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to rename set lists from the set lists screen popup menu and inline in the detail screen AppBar.

**Architecture:** The backend (`SetListService.updateSetList()`) already supports updating set list names. We add UI in two places: a rename dialog triggered from the popup menu on `SetListsScreen`, and inline title editing in `SetListDetailScreen`'s AppBar.

**Tech Stack:** Flutter, Drift (database), Riverpod (state)

---

### Task 1: Add rename dialog to SetListsScreen popup menu

**Files:**
- Modify: `lib/screens/setlists_screen.dart`

**Step 1: Add `_renameSetList` method**

Add this method to `_SetListsScreenState`, after the `_deleteSetList` method (line 111):

```dart
Future<void> _renameSetList(SetList setList) async {
  final nameController = TextEditingController(text: setList.name);

  final newName = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename Set List'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = nameController.text.trim();
            if (value.isNotEmpty) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );

  if (newName != null && newName != setList.name) {
    final updated = setList.copyWith(name: newName, modifiedAt: DateTime.now());
    await _setListService.updateSetList(updated);
  }
}
```

**Step 2: Add 'rename' case to PopupMenuButton onSelected**

In the `onSelected` callback of `PopupMenuButton` (around line 202), add a case for `'rename'`:

```dart
onSelected: (value) {
  switch (value) {
    case 'rename':
      _renameSetList(setList);
      break;
    case 'duplicate':
      _duplicateSetList(setList);
      break;
    case 'delete':
      _deleteSetList(setList);
      break;
  }
},
```

**Step 3: Add rename PopupMenuItem**

Insert this as the first item in `itemBuilder` (before the duplicate item, around line 212):

```dart
const PopupMenuItem(
  value: 'rename',
  child: Row(
    children: [
      Icon(Icons.edit),
      SizedBox(width: 8),
      Text('Rename'),
    ],
  ),
),
```

**Step 4: Run the app and verify**

Run: `make run-web`
- Open set lists screen
- Click the popup menu on a set list card
- Verify "Rename" appears as the first menu item
- Click Rename, change the name, submit
- Verify the name updates in the list

**Step 5: Commit**

```bash
git add lib/screens/setlists_screen.dart
git commit -m "feat: add rename option to set list popup menu"
```

---

### Task 2: Add inline title editing to SetListDetailScreen

**Files:**
- Modify: `lib/screens/setlist_detail_screen.dart`

**Step 1: Add state variables for inline editing**

Add these fields to `_SetListDetailScreenState` (after line 26):

```dart
bool _isEditingTitle = false;
late TextEditingController _titleController;
late FocusNode _titleFocusNode;
```

**Step 2: Initialize and dispose controllers**

Update `initState` (line 29):

```dart
@override
void initState() {
  super.initState();
  _titleController = TextEditingController();
  _titleFocusNode = FocusNode();
  _titleFocusNode.addListener(_onTitleFocusChange);
  _loadSetList();
}
```

Add a `dispose` override:

```dart
@override
void dispose() {
  _titleController.dispose();
  _titleFocusNode.removeListener(_onTitleFocusChange);
  _titleFocusNode.dispose();
  super.dispose();
}
```

**Step 3: Add focus change and save methods**

Add these methods after `_loadSetList`:

```dart
void _onTitleFocusChange() {
  if (!_titleFocusNode.hasFocus && _isEditingTitle) {
    _saveTitleEdit();
  }
}

void _startTitleEdit() {
  setState(() {
    _isEditingTitle = true;
    _titleController.text = _setList!.name;
  });
  _titleFocusNode.requestFocus();
}

Future<void> _saveTitleEdit() async {
  final newName = _titleController.text.trim();
  setState(() => _isEditingTitle = false);

  if (newName.isNotEmpty && newName != _setList!.name) {
    final updated = _setList!.copyWith(name: newName, modifiedAt: DateTime.now());
    await _setListService.updateSetList(updated);
    await _loadSetList();
  }
}

void _cancelTitleEdit() {
  setState(() => _isEditingTitle = false);
}
```

**Step 4: Replace AppBar title with editable widget**

Replace the AppBar title (line 136) from:

```dart
title: Text(_setList!.name),
```

to:

```dart
title: _isEditingTitle
    ? KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _cancelTitleEdit();
            }
          }
        },
        child: TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          style: Theme.of(context).appBarTheme.titleTextStyle ??
              Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: (_) => _saveTitleEdit(),
        ),
      )
    : GestureDetector(
        onTap: _startTitleEdit,
        child: Text(_setList!.name),
      ),
```

**Step 5: Add required import**

Add at the top of the file:

```dart
import 'package:flutter/services.dart';
```

**Step 6: Run and verify**

Run: `make run-web`
- Open a set list detail screen
- Tap the title — it should become editable
- Type a new name, press Enter — name saves
- Tap title again, press Escape — reverts to original
- Tap title, click elsewhere — name saves

**Step 7: Commit**

```bash
git add lib/screens/setlist_detail_screen.dart
git commit -m "feat: add inline title editing on set list detail screen"
```
