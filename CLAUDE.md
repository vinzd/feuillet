# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Feuillet is a forScore clone built with Flutter - a PDF sheet music reader with multi-layer annotation support and set list management. The app is designed for **local-only operation** with Syncthing for cross-device synchronization.

## Essential Commands

**Quick Start:** Use the Makefile for common tasks:
```bash
make setup          # Setup project from scratch
make run-web        # Fast development iteration (web)
make run-macos      # Run on macOS
make build-web      # Build for web deployment
make test           # Run all tests
make help           # See all available commands
```

### Development Setup

#### Using Makefile (Recommended)
```bash
# Complete setup from scratch
make setup

# Run on different platforms
make run-web        # Chrome (fastest hot reload)
make run-macos      # macOS native
make run-android    # Android emulator
```

#### Manual Setup
```bash
# Install dependencies
flutter pub get

# Generate database code (required after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Compile web worker (web platform only)
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.js

# Run the app
flutter run -d macos    # or android, ios, chrome
```

### Web Platform Support

The app supports web for **fast development iteration only**. Web has limited functionality:
- ✅ PDF import and display (stores PDFs as bytes in IndexedDB)
- ✅ Annotations, layers, set lists
- ✅ Full database persistence
- ❌ File system watching (Syncthing integration)
- ❌ Directory scanning

**Required web files:**
- `web/drift_worker.dart` - Source (tracked in git)
- `web/drift_worker.js` - Compiled (auto-generated, gitignored)
- `web/sqlite3.wasm` - SQLite engine (tracked in git, downloaded from releases)
- `web/index.html` - PDF.js CDN setup (tracked in git)

**Important:** Always use `make build-web` or `make run-web` instead of running `flutter build web` or `flutter run -d chrome` directly. The Makefile automatically compiles the drift worker and copies required files to the build output. Running Flutter commands directly will result in a missing `drift_worker.js` error.

```bash
# Build and serve web version
make build-web
make serve-web      # http://localhost:8080

# Or use hot reload
make run-web        # flutter run -d chrome
```

### Testing
```bash
# Using Makefile
make test                # Run all tests
make test-coverage       # With coverage report
make analyze             # Run flutter analyze

# Manual commands
flutter test
flutter test test/services/annotation_service_test.dart
flutter test --coverage
flutter test integration_test/app_test.dart -d macos
```

### Code Quality
```bash
# Using Makefile
make analyze        # Check for issues
make format         # Format all Dart code

# Build for release
make build-web          # Web
make build-macos        # macOS
make build-android      # Android APK
make build-all          # All platforms

# Manual commands
flutter analyze
dart format lib/ test/
flutter build apk --release
flutter build macos --release
flutter build ios --release
```

## Architecture

### Core Design Principles

1. **Local-First Architecture**: Everything runs locally using SQLite. The architecture allows future migration to server-client model but currently operates entirely offline.

2. **Syncthing Integration**: The app uses file system watchers to detect external changes from Syncthing, enabling peer-to-peer device synchronization without a server.

3. **Lifecycle-Aware File Watching**: File watchers are paused when the app goes to background (`AppLifecycleState.paused`) and resumed on foreground (`AppLifecycleState.resumed`) to conserve resources.

### Database Schema (Drift)

The database uses **WAL mode** (Write-Ahead Logging) for Syncthing compatibility, configured in `database.dart`:
```dart
await customStatement('PRAGMA journal_mode=WAL;');
```

**Tables:**
- `Documents` - PDF metadata with file paths, timestamps, page counts
- `DocumentSettings` - Per-document viewing preferences (zoom, brightness, contrast, current page)
- `AnnotationLayers` - Multiple layers per document with visibility and ordering
- `Annotations` - Drawing data stored as JSON (points, color, thickness) per page
- `SetLists` - Collections for performances
- `SetListItems` - Documents in set lists with ordering and notes

**Key Relationships:**
- One document → many annotation layers → many annotations
- One document → one document setting
- One set list → many set list items → many documents
- All use cascade delete (`onDelete: KeyAction.cascade`)

### Service Layer Pattern

All services follow a **singleton pattern** with lazy initialization:

```dart
class ServiceName {
  static ServiceName? _instance;
  static ServiceName get instance => _instance ??= ServiceName._();
  ServiceName._();
}
```

**Services:**
- `PdfService` - PDF import (file picker + drag-and-drop), library scanning, file management
- `AnnotationService` - Drawing stroke CRUD, JSON serialization
- `SetListService` - Set list CRUD, document ordering
- `FileWatcherService` - Monitors PDF directory and database for Syncthing changes

### State Management

Uses **Riverpod** for state management. The app root is wrapped in `ProviderScope` (see `main.dart`).

When creating new screens or features that need Riverpod, ensure they're descendants of `ProviderScope`.

### Annotation System Architecture

Annotations use a **multi-layer system**:
1. Each document can have multiple `AnnotationLayer`s
2. Each layer contains multiple `Annotation`s (one per page)
3. Each annotation stores drawing data as JSON:
   ```json
   {
     "points": [{"x": 10.0, "y": 20.0}, ...],
     "color": 4294901760,  // toARGB32()
     "thickness": 3.0,
     "type": "AnnotationType.pen"
   }
   ```
4. `DrawingCanvas` widget handles real-time drawing with gesture detection

**Important:** Use `Color.toARGB32()` for serialization (not the deprecated `.value` property).

### PDF Import

PDFs can be imported two ways:
1. **File Picker** - Via the import button, supports multi-select
2. **Drag-and-Drop** - Drag files from Finder/file manager directly into the library screen (desktop only)

Both methods use `PdfService` which handles:
- Copying files to the PDF directory with unique naming
- Adding entries to the database with metadata
- Validation (rejects non-PDF files with error feedback)
- Progress callbacks for batch imports

The drag-and-drop feature uses the `desktop_drop` package with `DropTarget` widget wrapping the library screen body.

### PDF Viewing Pipeline

1. `LibraryScreen` displays grid/list of PDFs via `PdfCard` widgets
2. Tapping opens `PdfViewerScreen` with `pdfx` controller
3. Settings are loaded from `DocumentSettings` table
4. Annotations are loaded per page from `Annotations` table
5. `DrawingCanvas` overlays on PDF for annotation mode
6. Settings and annotations persist on page change/app close

### File Watching & Syncthing Integration

`FileWatcherService` monitors two directories:
- PDF directory (`pdfs/`)
- Database file (`feuillet_db.sqlite` + WAL files)

**Filters Syncthing temporary files:**
- `.syncthing.*`
- `~syncthing~*`
- `*.tmp`
- `.~*`

When changes detected:
- PDF changes trigger library rescan via `PdfService.scanAndSyncLibrary()`
- Database changes handled via WAL mode (no explicit reload needed)

## Critical Implementation Details

### Drift Import Conflicts

When using Drift in screens, there's a naming conflict with Flutter's `Column` widget:
```dart
import 'package:drift/drift.dart' hide Column;
```

### cross_file Import for desktop_drop

The `desktop_drop` package uses `XFile` from `cross_file`. Import it with a lint ignore:
```dart
// ignore: depend_on_referenced_packages
import 'package:cross_file/cross_file.dart' show XFile;
```

### DateTime with Drift's Value Wrapper

When updating DateTime fields with `copyWith`, wrap in `Value()`:
```dart
document.copyWith(lastOpened: Value(DateTime.now()))
```

### Testing Considerations

**Widget tests involving full app initialization are skipped** because `FileWatcherService` creates background timers that don't complete before test teardown. This is documented in:
- `test/widget_test.dart`
- `test/screens/home_screen_test.dart`

For testing screens, test components in isolation with `ProviderScope` wrappers rather than full app initialization.

**Test binding initialization:**
```dart
TestWidgetsFlutterBinding.ensureInitialized();
```

### Color Serialization in Tests

Compare colors using `toARGB32()` not direct equality:
```dart
expect(restored.color.toARGB32(), original.color.toARGB32());
```

## Common Patterns

### Creating a New Screen

1. Add screen file to `lib/screens/`
2. If using Riverpod, wrap in `Consumer` or `ConsumerStatefulWidget`
3. For database access, use service layer (never direct queries in UI)
4. Add navigation route in parent screen

### Adding Database Tables

1. Define table class in `lib/models/database.dart`
2. Add to `@DriftDatabase` annotation
3. Run `dart run build_runner build --delete-conflicting-outputs`
4. Increment `schemaVersion` and add migration in `onUpgrade`

### Creating a New Service

1. Follow singleton pattern (see existing services)
2. Add database operations via `DatabaseService.database`
3. For async operations, return `Future`/`Stream`
4. Add corresponding tests in `test/services/`

### Adding Annotations Features

Annotations are **JSON-serialized** in the database. To add new annotation types:
1. Add to `AnnotationType` enum in `annotation_service.dart`
2. Update `DrawingStroke.toJson()` and `fromJson()` if needed
3. Update `DrawingCanvas` widget for rendering
4. Add tool UI in `PdfViewerScreen`

## Data Storage Locations

- **macOS**: `~/Library/Application Support/com.feuillet.app/feuillet/`
- **Android**: `/data/data/com.feuillet.feuillet/app_flutter/feuillet/`
- **iOS**: App Documents directory

Structure:
```
feuillet/
├── pdfs/                    # PDF files
├── feuillet_db.sqlite     # Main database
├── feuillet_db.sqlite-wal # WAL file
└── feuillet_db.sqlite-shm # Shared memory file
```

## Known Issues & Workarounds

1. **pdfx doesn't support `addListener()`** - removed page change listener code
2. **Watcher package uses `WatchEvent` not `FileSystemEvent`** - ensure correct type usage
3. **Timer pending in tests** - skip tests that initialize full app with FileWatcherService
4. **share_plus v12 API change** - Use `ShareParams` instead of deprecated positional arguments:
   ```dart
   // Old (deprecated)
   Share.shareXFiles([file], subject: 'title');
   // New
   Share.shareXFiles(ShareParams(files: [file], subject: 'title'));
   ```

## Future Architecture Considerations

The codebase is structured to support future migration to client-server:
- Service layer abstracts data operations
- Repository pattern can be added between services and database
- Local database can become cache layer
- Syncthing can be supplemented/replaced with cloud sync
