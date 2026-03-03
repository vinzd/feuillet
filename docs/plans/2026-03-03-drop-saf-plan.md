# Drop SAF, Use MANAGE_EXTERNAL_STORAGE Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all Android SAF code and use `MANAGE_EXTERNAL_STORAGE` permission with normal filesystem paths.

**Architecture:** Delete the Kotlin SAF method channel entirely. Simplify `FileAccessService` by removing all `isSafUri` branching — every method keeps only its `dart:io` path. Add `permission_handler` package for runtime permission requests. Remove SAF polling from `FileWatcherService`.

**Tech Stack:** Flutter, Dart, Kotlin, permission_handler package

---

### Task 1: Add permission_handler dependency and Android manifest permissions

**Files:**
- Modify: `pubspec.yaml` (add permission_handler)
- Modify: `android/app/src/main/AndroidManifest.xml` (add permissions)
- Modify: `android/app/build.gradle.kts` (if compileSdk needs updating)

**Step 1: Add permission_handler to pubspec.yaml**

Add under dependencies:

```yaml
  permission_handler: ^12.0.0
```

**Step 2: Add permissions to AndroidManifest.xml**

Add before `<application>`:

```xml
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

**Step 3: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully.

**Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "feat: add permission_handler and MANAGE_EXTERNAL_STORAGE permission"
```

---

### Task 2: Delete Kotlin SAF code and simplify MainActivity

**Files:**
- Delete: `android/app/src/main/kotlin/com/feuillet/app/SafMethodChannel.kt`
- Modify: `android/app/src/main/kotlin/com/feuillet/app/MainActivity.kt`

**Step 1: Delete SafMethodChannel.kt**

```bash
rm android/app/src/main/kotlin/com/feuillet/app/SafMethodChannel.kt
```

**Step 2: Simplify MainActivity.kt**

Replace entire file with:

```kotlin
package com.feuillet.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
```

**Step 3: Verify Android builds**

Run: `flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL (may have warnings, no errors)

**Step 4: Commit**

```bash
git add -A android/app/src/main/kotlin/com/feuillet/app/
git commit -m "feat: delete SAF method channel and simplify MainActivity"
```

---

### Task 3: Simplify FileAccessService — remove all SAF code

**Files:**
- Modify: `lib/services/file_access_service.dart`

**Step 1: Rewrite FileAccessService**

Remove:
- `isSafUri()` top-level function
- `_channel` MethodChannel constant
- All `_*Saf` private methods (`_listDocumentFilesSaf`, `_readFileBytesSaf`, `_writeFileSaf`, `_getFileMetadataSaf`)
- `copyToLocal()` method
- All `if (isSafUri(...))` branches in every method
- `_isAndroid` getter
- SAF-related imports (`package:flutter/services.dart`)

Keep only the `dart:io` code paths. The resulting file should have:
- `DocumentFileInfo` class (update doc comment to remove SAF mention, rename `uri` field to `path`)
- `FileMetadata` class (unchanged)
- `FileAccessService` singleton with these methods:
  - `pickDirectory()` — always uses `FilePicker.platform.getDirectoryPath()`
  - `listDocumentFiles(String directoryPath)` — uses `_listDocumentFilesLocal` logic directly
  - `readFileBytes(String filePath)` — `File(filePath).readAsBytes()`
  - `writeFileToDirectory(...)` — write with `File.writeAsBytes`
  - `fileExists(String filePath)` — `File(filePath).exists()`
  - `getFileMetadata(String filePath)` — `File(filePath).stat()`
  - `deleteFile(String filePath)` — `File(filePath).delete()`
  - `directoryExists(String path)` — `Directory(path).exists()`
  - `openPdfDocument(String filePath, {Uint8List? pdfBytes})` — remove SAF `copyToLocal` branch, keep `pdfBytes` and direct `openFile` paths

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/services/file_access_service.dart`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/services/file_access_service.dart
git commit -m "feat: remove SAF code from FileAccessService, use dart:io only"
```

---

### Task 4: Remove SAF references from FileWatcherService

**Files:**
- Modify: `lib/services/file_watcher_service.dart`

**Step 1: Remove SAF polling and isSafUri checks**

Remove:
- `import 'file_access_service.dart'` (only needed for `isSafUri`)
- `Timer? _safPollingTimer` field
- `Future<void> Function()? onSafPollCallback` field
- `_pollSafDirectory()` method
- All `isSafUri()` checks in `startWatching()`, `_startPdfDirectoryWatcher()`, `getPdfDirectoryPath()`
- `_safPollingTimer?.cancel()` from `stopWatching()` and `dispose()`

In `startWatching()`, the directory creation block becomes unconditional:
```dart
final pdfDir = Directory(_pdfDirectoryPath!);
if (!await pdfDir.exists()) {
  await pdfDir.create(recursive: true);
}
```

In `_startPdfDirectoryWatcher()`, remove the SAF polling early-return. Keep only the `DirectoryWatcher` logic.

In `getPdfDirectoryPath()`, remove the SAF check — always create directory if missing.

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/services/file_watcher_service.dart`
Expected: No issues found.

**Step 3: Commit**

```bash
git add lib/services/file_watcher_service.dart
git commit -m "feat: remove SAF polling from FileWatcherService"
```

---

### Task 5: Remove SAF references from DocumentService

**Files:**
- Modify: `lib/services/document_service.dart`

**Step 1: Remove SAF polling callback registration**

In `_initialize()`, remove line 68:
```dart
FileWatcherService.instance.onSafPollCallback = () => scanAndSyncLibrary();
```

**Step 2: Simplify _copyToDocumentDirectory**

Remove the `if (isSafUri(pdfDir))` branch (lines 168-171). Keep only the local file copy logic.

Remove the `import 'file_access_service.dart'` if `isSafUri` was the only thing used from it. Check — `FileAccessService.instance` is still used, so keep that import but `isSafUri` is no longer needed.

**Step 3: Simplify addDocumentToLibrary**

In `addDocumentToLibrary()`, the `fileName` extraction (line 458-459) currently has a SAF branch:
```dart
final fileName = isSafUri(filePath)
    ? p.basenameWithoutExtension(Uri.parse(filePath).pathSegments.last)
    : p.basenameWithoutExtension(filePath);
```

Replace with just:
```dart
final fileName = p.basenameWithoutExtension(filePath);
```

**Step 4: Verify no compile errors**

Run: `flutter analyze lib/services/document_service.dart`
Expected: No issues found.

**Step 5: Commit**

```bash
git add lib/services/document_service.dart
git commit -m "feat: remove SAF references from DocumentService"
```

---

### Task 6: Add permission request on Android startup

**Files:**
- Modify: `lib/main.dart` or the appropriate app initialization file

**Step 1: Find where the app initializes on Android**

Check `lib/main.dart` for the app startup flow. The permission request should happen early, before any file access.

**Step 2: Add permission request**

Add a function that requests `MANAGE_EXTERNAL_STORAGE` on Android:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestStoragePermission() async {
  if (!kIsWeb && Platform.isAndroid) {
    final status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }
}
```

Call this in `main()` before `FileWatcherService.instance.startWatching()` or equivalent.

**Step 3: Verify no compile errors**

Run: `flutter analyze lib/main.dart`
Expected: No issues found.

**Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: request MANAGE_EXTERNAL_STORAGE on Android startup"
```

---

### Task 7: Update tests — remove SAF tests, keep local tests

**Files:**
- Modify: `test/services/file_access_service_test.dart`
- Modify: `test/services/file_watcher_service_test.dart`

**Step 1: Update file_access_service_test.dart**

Remove:
- The `isSafUri` test group (lines 9-39) — function no longer exists
- The `DocumentFileInfo` test "works with SAF URIs" (lines 57-68) — update to use a local path instead
- The entire `FileAccessService SAF routing` test group (lines 252-323)

Update the `DocumentFileInfo` SAF test to use a regular path:
```dart
test('works with various path formats', () {
  final info = DocumentFileInfo(
    path: '/storage/emulated/0/documents/file.pdf',
    name: 'file.pdf',
    size: 2048,
    lastModified: DateTime(2024, 1, 15),
  );
  expect(info.name, 'file.pdf');
});
```

Note: If Task 3 renamed `DocumentFileInfo.uri` to `DocumentFileInfo.path`, update all test references accordingly.

**Step 2: Update file_watcher_service_test.dart**

Remove:
- The `SAF URI detection for file watching` test group (lines 43-74) — `isSafUri` no longer exists
- Remove `import 'package:feuillet/services/file_access_service.dart'` if no longer needed

**Step 3: Run tests**

Run: `flutter test test/services/file_access_service_test.dart test/services/file_watcher_service_test.dart`
Expected: All remaining tests pass.

**Step 4: Commit**

```bash
git add test/services/file_access_service_test.dart test/services/file_watcher_service_test.dart
git commit -m "test: remove SAF-specific tests"
```

---

### Task 8: Update CLAUDE.md — remove SAF documentation

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Remove SAF references from CLAUDE.md**

Search for and remove/update all SAF-related sections:
- Remove the "Android SAF Integration" section entirely
- Update "File Watching & Syncthing Integration" to remove SAF polling mentions
- Update "FileAccessService" description to remove SAF routing mention
- Remove `isSafUri` references
- Remove `copyToLocal` references
- Remove `content://` URI mentions
- Update "Data Storage Locations" to remove SAF URI mention
- Remove SAF method channel reference (`com.feuillet.app/saf`)

**Step 2: Add MANAGE_EXTERNAL_STORAGE note**

In the Android section, add a note that the app uses `MANAGE_EXTERNAL_STORAGE` permission for full filesystem access, with `permission_handler` package for runtime requests.

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: remove SAF references from CLAUDE.md, add MANAGE_EXTERNAL_STORAGE note"
```

---

### Task 9: Full test suite and analyze

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No issues found.

**Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

**Step 3: Final commit if any fixes needed**

Only if analysis or tests revealed issues to fix.
