.PHONY: help setup build test clean run-web run-macos run-android web-worker db-gen analyze format install-hooks

# Git commit hash for version display
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Default target
help:
	@echo "Feuillet - Development Makefile"
	@echo ""
	@echo "Setup & Dependencies:"
	@echo "  make setup           - Install dependencies and setup project from scratch"
	@echo "  make install-hooks   - Install git hooks (pre-commit formatting and analysis check)"
	@echo "  make web-worker      - Compile drift_worker.dart for web support"
	@echo "  make db-gen          - Generate database code from schema"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build-web       - Build for web (release)"
	@echo "  make build-macos     - Build for macOS (release)"
	@echo "  make build-android   - Build for Android (release)"
	@echo "  make build-all       - Build for all platforms"
	@echo ""
	@echo "Run Commands:"
	@echo "  make run-web         - Run on Chrome (development)"
	@echo "  make run-macos       - Run on macOS (development)"
	@echo "  make run-android     - Run on Android emulator (development)"
	@echo "  make serve-web       - Serve web build locally (port 8080)"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test            - Run all tests"
	@echo "  make test-coverage   - Run tests with coverage report"
	@echo "  make analyze         - Run flutter analyze"
	@echo "  make format          - Format all Dart code"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make clean-all       - Deep clean (including pub cache)"
	@echo "  make upgrade         - Upgrade all dependencies"

# Setup project from scratch
setup:
	@echo "🔧 Setting up Feuillet project..."
	flutter pub get
	@echo ""
	@echo "🗄️  Generating database code..."
	$(MAKE) db-gen
	@echo ""
	@echo "🌐 Compiling web worker..."
	$(MAKE) web-worker
	@echo ""
	@echo "🔗 Installing git hooks..."
	$(MAKE) install-hooks
	@echo ""
	@echo "✅ Setup complete! Use 'make run-web' or 'make run-macos' to start developing."

# Install git hooks (handles both regular repos and worktrees)
install-hooks:
	@echo "Installing git hooks..."
	@HOOKS_DIR=$$(git rev-parse --git-path hooks); \
	mkdir -p "$$HOOKS_DIR"; \
	if [ -f "$$HOOKS_DIR/pre-commit" ]; then \
		echo "⚠️  pre-commit hook already exists, backing up to pre-commit.backup"; \
		cp "$$HOOKS_DIR/pre-commit" "$$HOOKS_DIR/pre-commit.backup"; \
	fi; \
	cp hooks/pre-commit "$$HOOKS_DIR/pre-commit"; \
	chmod +x "$$HOOKS_DIR/pre-commit"; \
	echo "✓ Pre-commit hook installed (formats code and runs flutter analyze before each commit)"

# Generate database code using drift
db-gen:
	@echo "Generating database code..."
	dart run build_runner build --delete-conflicting-outputs

# Compile drift worker for web
web-worker:
	@echo "Compiling drift_worker.dart to JavaScript..."
	dart compile js -O4 web/drift_worker.dart -o web/drift_worker.js
	@echo "✅ Web worker compiled successfully"

# Build targets
build-web: web-worker
	@echo "🌐 Building for web (release)..."
	flutter build web --release --dart-define=GIT_HASH=$(GIT_HASH)
	@echo "Copying web worker files to build output..."
	cp -f web/sqlite3.wasm web/drift_worker.js build/web/
	@echo "✅ Web build complete: build/web/"

build-macos:
	@echo "🖥️  Building for macOS (release)..."
	flutter build macos --release --dart-define=GIT_HASH=$(GIT_HASH)
	@echo "✅ macOS build complete"

build-android:
	@echo "🤖 Building for Android (release)..."
	flutter build apk --release --dart-define=GIT_HASH=$(GIT_HASH)
	@echo "✅ Android APK: build/app/outputs/flutter-apk/app-release.apk"

build-ios:
	@echo "📱 Building for iOS (release)..."
	flutter build ios --release --no-codesign --dart-define=GIT_HASH=$(GIT_HASH)
	@echo "✅ iOS build complete"

build-all: build-web build-macos build-android
	@echo "✅ All platform builds complete"

# Run targets
run-web: web-worker
	@echo "🌐 Running on Chrome..."
	flutter run -d chrome --dart-define=GIT_HASH=$(GIT_HASH)

run-macos:
	@echo "🖥️  Running on macOS..."
	flutter run -d macos --dart-define=GIT_HASH=$(GIT_HASH)

run-android:
	@echo "🤖 Running on Android..."
	flutter run -d android --dart-define=GIT_HASH=$(GIT_HASH)

# Serve web build locally
serve-web: build-web
	@echo "🌐 Serving web build at http://localhost:8080"
	@echo "Press Ctrl+C to stop"
	cd build/web && python3 -m http.server 8080

# Testing
test:
	@echo "🧪 Running tests..."
	flutter test

test-coverage:
	@echo "🧪 Running tests with coverage..."
	flutter test --coverage
	@echo "Coverage report: coverage/lcov.info"

# Code quality
analyze:
	@echo "🔍 Running flutter analyze..."
	flutter analyze

format:
	@echo "✨ Formatting Dart code..."
	dart format lib/ test/

# Maintenance
clean:
	@echo "🧹 Cleaning build artifacts..."
	flutter clean
	rm -f web/drift_worker.js web/drift_worker.js.deps web/drift_worker.js.map
	@echo "✅ Clean complete"

clean-all: clean
	@echo "🧹 Deep cleaning (removing pub cache)..."
	rm -rf .dart_tool/
	rm -rf .flutter-plugins
	rm -rf .flutter-plugins-dependencies
	@echo "✅ Deep clean complete"

upgrade:
	@echo "⬆️  Upgrading dependencies..."
	flutter pub upgrade
	@echo ""
	@echo "🗄️  Regenerating database code..."
	$(MAKE) db-gen
	@echo ""
	@echo "🌐 Recompiling web worker..."
	$(MAKE) web-worker
	@echo "✅ Upgrade complete"

# Development workflow helpers
dev-web: clean setup run-web

dev-macos: clean setup run-macos

# Check if Flutter is installed
check-flutter:
	@command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter is not installed. Please install Flutter first."; exit 1; }
	@echo "✅ Flutter found: $$(flutter --version | head -1)"
