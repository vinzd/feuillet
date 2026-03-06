# Feuillet

[![CI](https://github.com/vinzd/feuillet/workflows/CI/badge.svg)](https://github.com/vinzd/feuillet/actions/workflows/ci.yml)
[![Build](https://github.com/vinzd/feuillet/workflows/Build%20All%20Platforms/badge.svg)](https://github.com/vinzd/feuillet/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.38.8-02569B?logo=flutter)](https://flutter.dev)

A sheet music reader built with Flutter — supports PDF, JPG, and PNG files with multi-layer annotations, labels, set lists, and cross-device sync. Available in English and French.

## 🌐 Try It Online

**[Launch Web Demo](https://vinzd.github.io/feuillet/)** - Test Feuillet directly in your browser

> **Note:** The web version has limitations - files are stored in browser storage (not file system), and file sync is not available. For full functionality, use the native macOS or Android apps.

## Features

### 📚 Document Library
- Import and organize PDF, JPG, and PNG sheet music files
- Grid and list view options
- Search functionality
- Automatic thumbnail generation
- File metadata tracking (page count, file size, last opened)
- **Drag-and-drop** import from file manager (desktop)

### 🏷️ Labels
- **Automatic labeling from directory structure** — a file at `Bach/Suites/Suite1.pdf` gets labeled "Bach" and "Suites"
- Manual label creation and assignment
- Color-coded labels with automatic palette cycling
- Filter library by one or more labels
- Batch label assignment on multi-selected documents

### 📖 Document Viewer
- **Pinch-to-zoom** with smooth gesture controls
- **Brightness and contrast adjustment** for optimal readability in any lighting condition
- **Per-document settings persistence** — zoom, contrast, and page position saved automatically
- Horizontal page navigation with smooth transitions (PDF)
- Full-screen reading mode with auto-hiding controls

### 🎨 Multi-Layer Annotations
- **Multiple annotation layers** per document
- Drawing tools:
  - Pen tool with customizable colors and thickness
  - Highlighter with transparency
  - Eraser tool
- **Layer management**:
  - Show/hide layers
  - Rename and reorder layers
  - Delete layers
- Annotations saved per page and synced across devices
- Color palette: Red, Blue, Green, Yellow, Black
- Adjustable stroke thickness

### 🎵 Set Lists
- Create and manage performance set lists
- Add documents to set lists with custom order
- Reorder documents via drag-and-drop
- **Performance mode** with:
  - Full-screen viewing
  - Quick navigation between documents
  - Progress indicator
  - Document list overlay
- Duplicate set lists
- Add notes to individual pieces

### 🔄 Cross-Device Sync
- Annotations stored as **`.feuillet.json` sidecar files** alongside documents — simple, portable JSON
- Set lists stored as **`.setlist.json` files** in a `setlists/` directory — shareable across devices
- **File system watchers** detect external changes and refresh automatically
- Timestamp-based conflict resolution (newest edit wins)
- Works with **any file sync tool**: [Syncthing](https://syncthing.net/), Dropbox, Google Drive, iCloud, OneDrive, etc.
- WAL mode SQLite for safe concurrent access
- Filters temporary files from sync tools

### 🌍 Localization
- Available in **English** and **French**
- Powered by Flutter's built-in localization with `.arb` files

## Architecture

### Technology Stack
- **Framework**: Flutter 3.x (Android, macOS, Web support)
- **Database**: Drift (SQLite with type-safe queries)
- **PDF Rendering**: pdfx
- **State Management**: Riverpod
- **File Watching**: watcher package

### Project Structure
```
lib/
├── main.dart                   # App entry point
├── l10n/                       # Localization (English, French)
├── models/
│   └── database.dart           # Drift database schema
├── services/
│   ├── database_service.dart   # Database lifecycle management
│   ├── file_watcher_service.dart  # File change monitoring
│   ├── sync_service.dart       # JSON sidecar import/export
│   ├── document_service.dart   # Document import and library scanning
│   ├── annotation_service.dart # Annotation management
│   ├── label_service.dart      # Label CRUD and auto-labeling
│   └── setlist_service.dart    # Set list operations
├── screens/
│   ├── home_screen.dart        # Main navigation
│   ├── library_screen.dart     # Document library view
│   ├── document_viewer_screen.dart  # Viewer with annotations
│   ├── setlists_screen.dart    # Set lists management
│   ├── setlist_detail_screen.dart   # Set list editing
│   ├── setlist_performance_screen.dart  # Performance mode
│   └── label_management_screen.dart # Label management
└── widgets/
    ├── document_card.dart      # Document thumbnail card
    ├── drawing_canvas.dart     # Annotation drawing
    └── layer_panel.dart        # Layer management UI
```

## Setup

### Prerequisites
- Flutter SDK 3.x or higher
- Dart SDK
- For Android: Android Studio and SDK
- For macOS: Xcode
- (Optional) A file sync tool for cross-device sync (Syncthing, Dropbox, Google Drive, etc.)

### Quick Start (Using Makefile)

```bash
# Complete setup from scratch
make setup

# Run for fast development
make run-web        # Chrome (fastest hot reload)
make run-macos      # macOS native
make run-android    # Android emulator

# Other commands
make help           # Show all available commands
make test           # Run tests
make build-web      # Build for web
```

### Manual Installation

1. **Clone the repository**
   ```bash
   cd feuillet
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate database code**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **(Web only) Compile drift worker**
   ```bash
   dart compile js -O4 web/drift_worker.dart -o web/drift_worker.js
   ```

5. **Run the app**
   ```bash
   # For Android
   flutter run -d android

   # For macOS
   flutter run -d macos

   # For Web (development iteration only)
   flutter run -d chrome
   ```

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS | ✅ Full support | Primary platform |
| Android | ✅ Full support | Native file system |
| Web | ⚠️ Limited | For development iteration only |
| iOS | ❌ Not built | No test device available |
| Windows | ❌ Not built | No test device available |
| Linux | ❌ Not built | No test device available |

> **iOS, Windows & Linux:** These platforms are not currently supported because the maintainer doesn't have access to these devices. Thanks to Flutter's cross-platform nature, adding support should be straightforward — contributions are welcome!

**Web limitations:**
- Files stored as bytes in IndexedDB (not file system)
- No file sync integration (no file watching)
- No directory scanning
- Use for fast UI/layout development with hot reload

## Cross-Device Sync Setup

Feuillet uses plain JSON files for sharing data between devices. Annotations are stored as `.feuillet.json` sidecar files next to each document, and set lists as `.setlist.json` files in a `setlists/` directory. This means **any file sync tool** that keeps a folder in sync across devices will work.

### Supported sync tools

- [Syncthing](https://syncthing.net/) (peer-to-peer, no cloud)
- Dropbox
- Google Drive
- iCloud Drive
- OneDrive
- Any other folder-sync tool

### 1. Locate the Feuillet document directory

The default location is:
- **macOS**: `~/Library/Application Support/com.feuillet.app/feuillet/pdfs/`
- **Android**: `/data/data/com.feuillet.feuillet/app_flutter/feuillet/pdfs/`

You can change this in the app settings. The directory contains:
```
pdfs/
├── Bach/
│   ├── Suite1.pdf
│   └── Suite1.pdf.feuillet.json   # annotations + labels
├── setlists/
│   └── Concert.setlist.json       # set list definition
└── ...
```

### 2. Point your sync tool at this directory

Configure your sync tool to keep the document directory in sync across your devices. Only the document directory needs syncing — the database is local-only and rebuilt from sidecar files on startup.

### 3. How it works

1. Feuillet watches the document directory for file changes
2. When your sync tool delivers new or updated files, the file watcher picks them up
3. The app automatically imports annotations, labels, and set lists from the JSON files
4. Changes you make locally are written back to JSON files, which your sync tool propagates
5. Timestamp-based conflict resolution ensures the newest edit wins

### Notes
- The app pauses file watching when in the background to save resources
- Temporary files from sync tools (`.tmp`, `.syncthing.*`, `.~*`) are filtered out automatically
- Close the app before large sync operations for best results

## Usage Guide

### Importing Documents
1. Tap the **+** button in the Library screen
2. Select PDF, JPG, or PNG files from your device
3. Files are copied to Feuillet's managed directory
4. Subdirectories are scanned recursively — directory names become labels automatically
5. On desktop, you can also **drag and drop** files directly into the library

### Viewing Documents
1. Tap any document in the library to open it
2. Pinch to zoom in/out
3. Tap the screen to show/hide controls
4. Use the **Display Settings** button (tune icon) to adjust brightness and contrast
5. Navigate pages with left/right buttons or swipe gestures

### Adding Annotations
1. Open a document
2. Tap the **pen icon** to enter annotation mode
3. Select a tool (pen, highlighter, or eraser)
4. Choose a color
5. Adjust thickness by tapping the line weight icon
6. Draw on the PDF
7. Tap the **layers icon** to manage layers

### Creating Set Lists
1. Go to the **Set Lists** tab
2. Tap the **+** button
3. Enter a name and optional description
4. Add documents from your library
5. Reorder by dragging
6. Tap the **play icon** to start performance mode

### Performance Mode
- Swipe or use arrows to navigate between pieces
- Tap to show/hide controls
- Tap the list icon to jump to a specific document
- Full-screen view optimized for reading while performing

## Development

### Using Makefile (Recommended)

```bash
# Show all commands
make help

# Development workflow
make setup          # Setup from scratch
make run-web        # Fast development (hot reload)
make run-macos      # Run on macOS
make test           # Run all tests
make analyze        # Static analysis
make format         # Format code

# Building
make build-web      # Build for web
make build-macos    # Build for macOS
make build-android  # Build Android APK
make build-all      # Build all platforms

# Maintenance
make clean          # Clean build artifacts
make upgrade        # Upgrade dependencies
```

### Manual Commands

```bash
# Running Tests
flutter test
flutter test --coverage

# Building for Release
flutter build apk --release      # Android
flutter build macos --release    # macOS
flutter build web --release      # Web

# Regenerating Database Code
dart run build_runner build --delete-conflicting-outputs

# Compiling Web Worker
dart compile js -O4 web/drift_worker.dart -o web/drift_worker.js
```

## CI/CD

The project uses GitHub Actions for continuous integration and deployment:

### Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **CI** | Push, PR to `main`/`develop` | Run tests, analysis, and build web |
| **Build All Platforms** | Manual, version tags | Build Android, macOS, Web |
| **Release** | Version tags (`v*.*.*`) | Create GitHub releases with artifacts |
| **Deploy to Pages** | Push to `main` | Deploy web version to GitHub Pages |

### Running CI Locally

```bash
# Run the same checks as CI
make format     # Check formatting
make analyze    # Run static analysis
make test       # Run all tests
make build-web  # Build web version
```

### Creating a Release

1. Update `CHANGELOG.md` with changes
2. Commit and push changes
3. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub Actions will automatically:
   - Build for all platforms
   - Create a GitHub release
   - Upload all build artifacts

### Dependabot

Dependabot automatically:
- Updates Flutter/Dart dependencies weekly
- Updates GitHub Actions weekly
- Creates pull requests for updates

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Quick start:**
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes with tests
4. Ensure CI passes: `make analyze && make test`
5. Commit: `git commit -m 'feat: add amazing feature'`
6. Push and open a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

MIT License - feel free to use this project for your own purposes.

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- PDF rendering powered by [pdfx](https://pub.dev/packages/pdfx)
- Database management by [Drift](https://drift.simonbinder.eu/)
- Cross-device sync via file-based JSON sidecars (works with [Syncthing](https://syncthing.net/), Dropbox, and others)
