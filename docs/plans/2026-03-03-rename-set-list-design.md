# Rename Set List — Design

## Summary

Add the ability to rename a set list from two places: the set lists screen popup menu and inline in the detail screen AppBar.

## Entry Points

### 1. Set Lists Screen — Popup Menu

Add a "Rename" item to the existing PopupMenuButton (alongside Duplicate and Delete). Selecting it opens an AlertDialog with a TextField pre-filled with the current name. Submit updates via `SetListService.updateSetList()`.

### 2. Detail Screen — Inline Title Editing

Tapping the title text in the AppBar switches it to a TextField for inline editing. Saving triggers:
- Press Enter
- Tap outside (focus lost)

Reverting triggers:
- Press Escape

### Behavior

- Empty or whitespace-only names are rejected; the original name is kept
- `modifiedAt` timestamp updates on rename (handled by `updateSetList`)
- Sync writes are triggered automatically by the service layer

### Scope

Name only. Description editing is out of scope.

## Files

- `lib/screens/setlists_screen.dart` — Rename menu item + rename dialog
- `lib/screens/setlist_detail_screen.dart` — Inline title editing in AppBar
