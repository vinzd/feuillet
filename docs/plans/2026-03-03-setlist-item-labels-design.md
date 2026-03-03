# Set List Item Labels

## Problem

Users need to give custom labels to documents within set lists (e.g., "Introduction" for "Sonate.pdf") to describe the role a score plays in a performance.

## Design

### Data Layer

No schema migration. Repurpose the existing `notes` TEXT column on `SetListItems` as the label. Rename service parameters from `notes` to `label` for clarity. Add `updateSetListItemLabel(itemId, label)` to `SetListService`.

### Set List Detail Screen

Each item row gains a label line below the document name, in lighter/italic style. When empty, a tappable "Add label" placeholder appears. Tapping switches to an inline `TextField`; saves on focus loss or Enter.

### Performance Mode (Bottom Controls)

Show the label beside the document name (e.g., "Sonate.pdf — Introduction"). When no label exists, show just the filename.

### Sync

Labels travel with the database. No special Syncthing handling needed.
