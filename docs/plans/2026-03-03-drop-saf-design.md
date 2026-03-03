# Design: Replace SAF with MANAGE_EXTERNAL_STORAGE

## Goal

Remove all Android SAF (Storage Access Framework) code and use `MANAGE_EXTERNAL_STORAGE` permission instead, so all file access uses normal filesystem paths via `dart:io`.

## Changes

### Android native (Kotlin)

- Delete `SafMethodChannel.kt`
- Remove SAF registration from `MainActivity.kt`
- Add `MANAGE_EXTERNAL_STORAGE` and `READ_EXTERNAL_STORAGE` to `AndroidManifest.xml`
- Add runtime permission request using `permission_handler` Flutter package

### Dart — FileAccessService

- Remove `isSafUri()` function and all `content://` branching
- Each method keeps only the `dart:io` path (current "else" branch)
- Remove `copyToLocal()` — all paths are real filesystem paths
- `pickDirectory()` on Android uses `file_picker` (`FilePicker.platform.getDirectoryPath()`)
- `openPdfDocument()` simplified — no SAF copy step

### Dart — FileWatcherService

- Remove `_safPollingTimer`, `onSafPollCallback`, and SAF polling logic
- All directories use native `DirectoryWatcher` uniformly

### Dart — DocumentService

- Remove SAF polling callback registration

### Tests

- Remove SAF-specific test cases (isSafUri, channel routing, polling)
- Simplify remaining tests to cover `dart:io` paths only

## What stays the same

- Database schema unchanged (paths are strings, just never `content://` URIs)
- AppSettingsService still manages configurable PDF directory path
- All service interfaces stay the same — callers don't change
- Import flow, annotation system, export untouched

## Permission flow

On Android app start or first directory pick, request `MANAGE_EXTERNAL_STORAGE` via `permission_handler` package.
