# Changelog

All notable changes to Feuillet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-10

### Added
- Document rename, with automatic sidecar rename and set list reference updates
- Viewer title refreshes after rename, with web support and keyboard shortcuts

### Changed
- Viewer header actions collapse into an overflow menu on phones for better mobile ergonomics
- `DrawingCanvas` now uses raw pointer events to capture full strokes accurately
- Upgraded to Flutter 3.41.9, Drift 2.33.0, sqlite3 3.3.1, file_picker 11.0.2, desktop_drop 0.7.1

### Fixed
- Prevent accidental selection mode when scrolling the library
- Suppress fullscreen toggle while in annotation mode
- Exit annotation mode when closing the floating panel
- Resolve set list sync issues on document directory change and stabilize set list IDs

## [0.1.0] - 2026-03-06

First stable release of Feuillet — a local-first sheet music reader.

- PDF and image (JPG, PNG) library with import, search, sorting, and labels
- Multi-layer annotation system with pen, highlighter, and eraser tools
- Set list management for organizing performances
- Cross-device sync via sidecar files (works with Syncthing, Dropbox, etc.)

[0.2.0]: https://github.com/vinzd/feuillet/releases/tag/v0.2.0
[0.1.0]: https://github.com/vinzd/feuillet/releases/tag/v0.1.0
