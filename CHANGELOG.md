# Changelog

All notable changes to Feuillet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Web platform support for fast development iteration
- PDF import and display on web (using IndexedDB)
- GitHub Actions CI/CD workflows
- Makefile for easy project setup and building
- Comprehensive documentation

### Changed
- Updated database schema to support PDF bytes storage (for web)
- Improved cross-platform compatibility

## [0.1.0] - 2026-01-28

### Added
- Initial release
- PDF library management with import and organization
- Advanced PDF viewer with zoom, pan, brightness, and contrast controls
- Multi-layer annotation system with pen, highlighter, and eraser tools
- Set list management for performances
- Performance mode with full-screen viewing
- Syncthing integration for cross-device sync (native platforms)
- File system watchers for automatic library updates
- WAL mode SQLite for better concurrent access
- Support for macOS, iOS, and Android platforms

### Features
- Grid and list view for PDF library
- Per-document settings persistence
- Multiple annotation layers per document
- Layer management (show/hide, rename, reorder, delete)
- Color palette with 5 colors and adjustable thickness
- Drag-and-drop reordering in set lists
- Auto-hiding controls in viewer mode
- Dark mode support

[Unreleased]: https://github.com/yourusername/feuillet/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/feuillet/releases/tag/v0.1.0
