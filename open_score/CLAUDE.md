# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Open Score is a forScore clone built with Flutter - a PDF sheet music reader with multi-layer annotation support and set list management. The app is designed for **local-only operation** with Syncthing for cross-device synchronization.

## Essential Commands

### Development Setup
```bash
# Install dependencies
flutter pub get

# Generate database code (required after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run -d macos    # or android, ios
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/annotation_service_test.dart

# Run with coverage
flutter test --coverage

# Run integration tests (requires device/emulator)
flutter test integration_test/app_test.dart -d macos
```

### Code Quality
```bash
# Check for issues
flutter analyze

# Build for release
flutter build apk --release      # Android
flutter build macos --release    # macOS
flutter build ios --release      # iOS
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
- `PdfService` - PDF import, library scanning, file management
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
- Database file (`open_score_db.sqlite` + WAL files)

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

- **macOS**: `~/Library/Application Support/com.openscore.openScore/open_score/`
- **Android**: `/data/data/com.openscore.open_score/app_flutter/open_score/`
- **iOS**: App Documents directory

Structure:
```
open_score/
├── pdfs/                    # PDF files
├── open_score_db.sqlite     # Main database
├── open_score_db.sqlite-wal # WAL file
└── open_score_db.sqlite-shm # Shared memory file
```

## Known Issues & Workarounds

1. **pdfx doesn't support `addListener()`** - removed page change listener code
2. **Watcher package uses `WatchEvent` not `FileSystemEvent`** - ensure correct type usage
3. **Timer pending in tests** - skip tests that initialize full app with FileWatcherService

## Future Architecture Considerations

The codebase is structured to support future migration to client-server:
- Service layer abstracts data operations
- Repository pattern can be added between services and database
- Local database can become cache layer
- Syncthing can be supplemented/replaced with cloud sync
