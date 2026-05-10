# Feuillet

[![CI](https://github.com/vinzd/feuillet/workflows/CI/badge.svg)](https://github.com/vinzd/feuillet/actions/workflows/ci.yml)
[![Build](https://github.com/vinzd/feuillet/workflows/Build%20All%20Platforms/badge.svg)](https://github.com/vinzd/feuillet/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)

A local-first sheet music reader built with Flutter. Reads PDF, JPG, and PNG files with multi-layer annotations, labels, and set lists. Available in English and French.

**[Try the web demo](https://vinzd.github.io/feuillet/)** (limited — no file system access).

## Not "cloud sync" — just files on disk

Feuillet does **not** ship a cloud backend, account system, or proprietary sync protocol. It transparently sits on top of a regular folder on your filesystem:

- Documents are plain `.pdf` / `.jpg` / `.png` files.
- Annotations are stored as `.feuillet.json` sidecar files next to each document.
- Set lists are stored as `.setlist.json` files in a `setlists/` subfolder.

The app watches the folder and reacts to whatever changes happen there — whether you renamed a file in Finder, dropped a new PDF in via SSH, or had Syncthing/Dropbox/iCloud/Google Drive deliver an update from another device. Pick any sync tool (or none); Feuillet doesn't care how the bytes get there.

The local SQLite database holds your shared content (documents, annotations, labels, set lists) as well as device-local state that doesn't sync — per-document viewing settings (zoom, brightness, contrast, last page) and app preferences like the configured library directory.

## Features

- **Library** — import PDF/JPG/PNG, drag-and-drop on desktop, recursive folder scan, search, grid/list views, thumbnails, multi-select.
- **Auto-labels from folders** — `Bach/Suites/Suite1.pdf` is labeled `Bach` and `Suites` automatically. Manual labels with color palette also supported.
- **Viewer** — pinch-zoom, pan, brightness/contrast, per-document persistence (zoom, page, settings). Header collapses into an overflow menu on small screens.
- **Annotations** — multiple layers per document, pen / highlighter / eraser, color and thickness controls, layer show/hide/rename/reorder. Strokes use raw pointer events for accurate capture.
- **Document rename** — renaming a document also renames its sidecar and updates references in set lists.
- **Set lists** — create, reorder via drag-and-drop, performance mode with quick navigation between pieces.
- **Localization** — English and French.

## Platform support

| Platform | Status                                                  |
|----------|---------------------------------------------------------|
| macOS    | Full support                                            |
| Android  | Full support (uses `MANAGE_EXTERNAL_STORAGE`)           |
| Web      | Limited — IndexedDB storage, no file watching, dev only |
| iOS / Windows / Linux | Not built — contributions welcome              |

## Quick start

```bash
make setup          # install deps, generate code, compile web worker
make run-macos      # or: make run-android, make run-web
make test
make build-all
```

See `make help` for the full list of targets.

Default document directory (configurable in app settings):
- **macOS**: `~/Library/Application Support/com.feuillet.app/feuillet/pdfs/`
- **Android**: `/data/data/com.feuillet.feuillet/app_flutter/feuillet/pdfs/`

## Architecture

- **Flutter** (Android, macOS, Web)
- **Drift** (SQLite, type-safe, WAL mode for safe concurrent access)
- **Riverpod** for state management
- **pdfx** for PDF rendering, **watcher** for file system events

See [`CLAUDE.md`](CLAUDE.md) for a deeper architectural tour.

## Releases

Tags `v*.*.*` trigger a GitHub Actions workflow that builds Android APK, macOS `.app`, and web bundle, and attaches them to a GitHub release.

```bash
# Update CHANGELOG.md and pubspec.yaml version, then:
git tag v0.2.0
git push origin v0.2.0
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `make analyze && make test` before opening a PR.

## License

MIT.
