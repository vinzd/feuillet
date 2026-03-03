# Sync Annotations & Set Lists via Syncthing

## Context

Feuillet currently syncs only score files (PDFs, images) via Syncthing. Annotations, layers, and set lists live in the local SQLite database and don't travel between devices.

**Goal:** Sync annotations and set lists across the user's own devices using Syncthing's existing file-based sync, with last-write-wins conflict resolution.

**Not in scope:** Document settings (zoom, brightness, current page), multi-user sharing, merge-based conflict resolution.

## Approach: Sidecar JSON Files

Annotations and set lists are exported as JSON files into the Syncthing-watched document directory. The existing file watcher detects incoming changes and imports them into the local database.

## File Format: Annotation Sidecars

Each score file gets a companion `.feuillet.json` in the same directory:

```
pdfs/
├── Bach - Cello Suite 1.pdf
├── Bach - Cello Suite 1.feuillet.json
├── subfolder/
│   ├── Debussy - Clair de Lune.png
│   ├── Debussy - Clair de Lune.feuillet.json
```

Schema:

```json
{
  "version": 1,
  "modifiedAt": "2026-03-03T14:30:00Z",
  "layers": [
    {
      "name": "Main",
      "isVisible": true,
      "orderIndex": 0,
      "annotations": [
        {
          "pageNumber": 0,
          "strokes": [
            {
              "points": [{"x": 10.0, "y": 20.0}],
              "color": 4294901760,
              "thickness": 3.0,
              "type": "AnnotationType.pen"
            }
          ]
        }
      ]
    }
  ]
}
```

- File name: `<score-basename>.feuillet.json`
- Reuses existing `DrawingStroke.toJson()`/`fromJson()` format
- `version` field for future format evolution
- `modifiedAt` used for last-write-wins comparison
- No sidecar written if a document has zero annotations; sidecar deleted when all annotations are removed

## File Format: Set List Files

Set lists live in a `setlists/` subfolder:

```
pdfs/
├── setlists/
│   ├── Concert Dec 2026.setlist.json
│   ├── Practice Rotation.setlist.json
```

Schema:

```json
{
  "version": 1,
  "modifiedAt": "2026-03-03T14:30:00Z",
  "name": "Concert Dec 2026",
  "description": "Winter recital program",
  "items": [
    {
      "documentPath": "Bach - Cello Suite 1.pdf",
      "orderIndex": 0,
      "notes": "Open with this, no repeat"
    },
    {
      "documentPath": "subfolder/Debussy - Clair de Lune.png",
      "orderIndex": 1,
      "notes": null
    }
  ]
}
```

- File name: `<sanitized-set-list-name>.setlist.json`
- Documents referenced by relative path from document directory root (not DB IDs)
- Missing documents are kept in JSON but hidden in UI until the score arrives
- File name collision (after sanitization): append short hash suffix

## Write Behavior (Local Changes to Files)

- **Annotations:** Write sidecar on page change, app close, or leaving annotation mode. Debounce writes (2 seconds) during active annotation.
- **Set lists:** Write `.setlist.json` on create/modify. Delete file on set list deletion.
- **Atomic writes:** Write to `.tmp` then rename to avoid Syncthing picking up partial files.
- All writes go through `FileAccessService` (handles Android SAF URIs).

## Watch Behavior (Incoming Files to Database)

- Extend `FileWatcherService` to react to `.feuillet.json` and `.setlist.json` changes.
- On changed sidecar: compare `modifiedAt` with local DB. If file is newer, import (replace local annotations for that document).
- On changed set list file: same logic. If file is newer, replace local set list.
- On deleted `.setlist.json`: delete corresponding local set list.
- Sidecar deletions are not propagated (score deletion already cascades annotations via DB).

## Loop Suppression

After importing a sidecar from disk, set a short suppression flag (~1 second) so the write triggered by the DB change doesn't cause the file watcher to re-import. Prevents: file arrives -> import to DB -> DB triggers sidecar write -> Syncthing sees change -> loop.

## Startup Reconciliation

On app launch, scan all `.feuillet.json` and `.setlist.json` files and reconcile with the database using `modifiedAt` timestamps (newer wins).

## Edge Cases

- **Score not yet synced:** Sidecar ignored until score arrives; next scan picks it up.
- **Renamed/moved scores:** Sidecar moves with the score in the directory tree. `scanAndSyncLibrary()` handles path changes.
- **Set list references deleted document:** Item hidden in UI, reappears if document is re-synced.
- **Android SAF:** All file I/O through `FileAccessService` which handles SAF URIs.

## Architecture Changes

- **New service:** `SyncService` — orchestrates import/export, debouncing, loop suppression, startup reconciliation.
- **Modified:** `AnnotationService` (trigger sidecar write on save), `SetListService` (trigger set list file write on change), `FileWatcherService` (react to `.feuillet.json`/`.setlist.json`).
- **No new dependencies** — JSON file I/O through existing `FileAccessService`.
