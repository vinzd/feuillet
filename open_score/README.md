# Open Score

A forScore clone built with Flutter - a powerful PDF sheet music reader with annotation and set list management capabilities.

## Features

### 📚 PDF Library Management
- Import and organize PDF sheet music files
- Grid and list view options
- Search functionality
- Automatic thumbnail generation
- File metadata tracking (page count, file size, last opened)

### 📖 Advanced PDF Viewer
- **Pinch-to-zoom** with smooth gesture controls
- **Brightness and contrast adjustment** for optimal readability in any lighting condition
- **Per-document settings persistence** - zoom, contrast, and page position saved automatically
- Horizontal page navigation with smooth transitions
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
- Annotations saved per page and synced across devices via Syncthing
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

### 🔄 Syncthing Integration
- **File system watchers** monitor for external changes
- Automatic library refresh when PDFs are synced
- Database synchronization across devices
- WAL mode SQLite for better concurrent access
- Filters Syncthing temporary files

## Architecture

### Technology Stack
- **Framework**: Flutter 3.x (Android, macOS, iOS support)
- **Database**: Drift (SQLite with type-safe queries)
- **PDF Rendering**: pdfx
- **State Management**: Riverpod
- **File Watching**: watcher package

### Project Structure
```
lib/
├── main.dart                   # App entry point
├── models/
│   └── database.dart           # Drift database schema
├── services/
│   ├── database_service.dart   # Database lifecycle management
│   ├── file_watcher_service.dart  # Syncthing file monitoring
│   ├── pdf_service.dart        # PDF operations
│   ├── annotation_service.dart # Annotation management
│   └── setlist_service.dart    # Set list operations
├── screens/
│   ├── home_screen.dart        # Main navigation
│   ├── library_screen.dart     # PDF library view
│   ├── pdf_viewer_screen.dart  # PDF viewer with annotations
│   ├── setlists_screen.dart    # Set lists management
│   ├── setlist_detail_screen.dart  # Set list editing
│   └── setlist_performance_screen.dart  # Performance mode
└── widgets/
    ├── pdf_card.dart           # PDF thumbnail card
    ├── drawing_canvas.dart     # Annotation drawing
    └── layer_panel.dart        # Layer management UI
```

## Setup

### Prerequisites
- Flutter SDK 3.x or higher
- Dart SDK
- For Android: Android Studio and SDK
- For macOS/iOS: Xcode
- (Optional) Syncthing for cross-device sync

### Installation

1. **Clone the repository**
   ```bash
   cd open_score
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate database code**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**
   ```bash
   # For Android
   flutter run -d android

   # For macOS
   flutter run -d macos

   # For iOS
   flutter run -d ios
   ```

## Syncthing Setup for Multi-Device Sync

### 1. Install Syncthing
- **macOS**: `brew install syncthing`
- **Android**: Install from [Google Play](https://play.google.com/store/apps/details?id=com.nutomic.syncthingandroid)
- **iOS**: Use [Möbius Sync](https://apps.apple.com/app/mobius-sync/id1539203216)

### 2. Locate Open Score Data Directory

The app stores data in:
- **macOS**: `~/Library/Application Support/com.openscore.openScore/open_score/`
- **Android**: `/data/data/com.openscore.open_score/app_flutter/open_score/`
- **iOS**: App's Documents directory

You can find the exact path in the app by checking debug logs or settings.

### 3. Configure Syncthing

1. Create a new folder in Syncthing pointing to the Open Score directory
2. Share this folder with your other devices
3. The folder contains:
   - `pdfs/` - Your PDF files
   - `open_score_db.sqlite` - The database
   - Database WAL files (`.sqlite-wal`, `.sqlite-shm`)

### 4. Important Syncthing Settings

- **File versioning**: Recommended to enable "Simple File Versioning" to prevent data loss
- **Ignore patterns**: The app automatically filters Syncthing temp files
- **Watch for changes**: Enable for instant sync

### 5. How It Works

1. Open Score monitors the PDF directory and database file
2. When Syncthing syncs changes, the file watcher detects them
3. The app automatically:
   - Reloads the database
   - Refreshes the library
   - Updates annotations
4. Changes made on one device appear on others within seconds

### Notes
- Close the app before large sync operations for best results
- The app pauses file watching when in background to save resources
- Database uses WAL mode to minimize lock conflicts during sync

## Usage Guide

### Importing PDFs
1. Tap the **+** button in the Library screen
2. Select a PDF file from your device
3. The file is copied to Open Score's managed directory
4. Alternatively, add PDFs directly via Syncthing

### Viewing PDFs
1. Tap any PDF in the library to open it
2. Pinch to zoom in/out
3. Tap the screen to show/hide controls
4. Use the **Display Settings** button (tune icon) to adjust brightness and contrast
5. Navigate pages with left/right buttons or swipe gestures

### Adding Annotations
1. Open a PDF
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

## Roadmap / Future Enhancements

- [ ] Text annotations
- [ ] Audio/metronome integration
- [ ] PDF cropping and rotation
- [ ] Bookmark favorites
- [ ] Advanced search (by composer, key, etc.)
- [ ] Cloud sync option (in addition to Syncthing)
- [ ] Backup/restore functionality
- [ ] Custom color palettes
- [ ] Handwriting recognition for annotations
- [ ] MIDI controller support
- [ ] Web version support

## Development

### Running Tests
```bash
flutter test
```

### Building for Release
```bash
# Android
flutter build apk --release

# macOS
flutter build macos --release

# iOS
flutter build ios --release
```

### Regenerating Database Code
After modifying the database schema:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Contributing

This is a personal project, but contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - feel free to use this project for your own purposes.

## Acknowledgments

- Inspired by [forScore](https://forscore.co/)
- Built with [Flutter](https://flutter.dev/)
- PDF rendering powered by [pdfx](https://pub.dev/packages/pdfx)
- Database management by [Drift](https://drift.simonbinder.eu/)
- Cross-device sync via [Syncthing](https://syncthing.net/)
