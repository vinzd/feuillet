# Document Labels Design

**Issue:** #74 — Add labels to documents
**Date:** 2026-03-04

## Summary

Add a label/tag system for documents. Labels can be used to filter documents in the library. By default, directory names from the relative path are auto-applied as labels. Users can attach arbitrary labels (with optional colors) to documents, including in batch mode. Labels sync across devices via the existing `.feuillet.json` sidecar files.

## Database Schema (v5 → v6)

```sql
Labels (
  name TEXT PRIMARY KEY,
  color INTEGER  -- nullable, ARGB32 format
)

DocumentLabels (
  documentId INTEGER REFERENCES Documents(id) ON DELETE CASCADE,
  labelName TEXT REFERENCES Labels(name) ON DELETE CASCADE ON UPDATE CASCADE,
  PRIMARY KEY (documentId, labelName)
)
```

- `name` as primary key — labels are identified by name (matches sidecar format)
- `ON UPDATE CASCADE` on `labelName` — renaming propagates automatically
- Both FKs cascade on delete

## Service Layer

New `LabelService` singleton:

- **CRUD:** `createLabel`, `deleteLabel`, `updateLabelColor`, `renameLabel`
- **Associations:** `addLabelToDocument`, `removeLabelFromDocument`, `addLabelToDocuments` (batch)
- **Queries:** `getLabelsForDocument`, `getAllLabels`, `getDocumentsByLabels` (AND logic)
- **Streams:** `watchAllLabels`, `watchDocumentLabels` (reactive UI)

**Auto-labeling from directories** (in `DocumentService.scanAndSyncLibrary`):
- Compute relative path from PDF directory root
- Extract each subdirectory segment as a label name
- Auto-create labels and associations if they don't exist

## Sidecar Sync

Extend `.feuillet.json`:

```json
{
  "version": 2,
  "labels": [
    {"name": "Classical", "color": 4294901760},
    {"name": "Bach"}
  ],
  "annotations": { ... }
}
```

- Export: write current labels into sidecar on label change
- Import: read labels from sidecar, create-or-match by name, associate with document
- Color conflict resolution: keep local color if label already exists

## UI

### Library Screen Filter Bar
- Horizontal scrollable row of label chips (below search bar)
- Each chip: label name + optional color dot
- Tap to toggle; AND logic (all selected labels must match)
- "Clear filters" action when any label is selected

### Single Document Labeling
- In document viewer/info sheet: current labels as chips
- "+" to add (autocomplete from existing, or create new)
- "x" to remove from document

### Batch Labeling
- Uses existing multi-select (long-press drag)
- "Label" icon in selection toolbar
- Dialog with all labels as checkboxes
- Apply adds checked labels to all selected documents

### Label Management
- "Manage Labels" screen (from settings or menu)
- Edit color, rename, or delete labels
