# Feuillet Test Suite

This document describes the comprehensive test suite for Feuillet.

## Test Structure

The test suite is organized into the following categories:

### 1. Unit Tests (`test/`)

Unit tests verify individual components in isolation.

#### Services Tests (`test/services/`)

- **annotation_service_test.dart**
  - DrawingStroke serialization/deserialization
  - JSON roundtrip preservation
  - All annotation types defined
  - Service instantiation

- **pdf_service_test.dart**
  - Singleton pattern consistency
  - PDF file extension validation
  - Service initialization

- **file_watcher_service_test.dart**
  - Singleton pattern consistency
  - Stream availability
  - Syncthing temp file pattern detection

- **setlist_service_test.dart**
  - Service instantiation
  - Order index management
  - Reordering logic

#### Models Tests (`test/models/`)

- **database_test.dart**
  - Document model creation and copyWith
  - SetList model
  - AnnotationLayer model
  - DocumentSetting model
  - Annotation model
  - SetListItem model
  - File size formatting
  - Page count validation

#### Widget Tests (`test/widgets/`)

- **drawing_canvas_test.dart**
  - Widget renders without error
  - Accepts different tools (pen, highlighter, eraser, text)
  - Accepts different colors
  - Accepts different thickness values

- **pdf_card_test.dart**
  - Displays document name
  - Displays page count
  - Handles tap events
  - Renders with various page counts

#### Screen Tests (`test/screens/`)

- **home_screen_test.dart**
  - Navigation bar renders
  - Shows Library and Set Lists tabs
  - Tab switching functionality
  - Icon display

### 2. Widget Tests (`test/widget_test.dart`)

- Basic app launch test
- Navigation verification

### 3. Integration Tests (`integration_test/`)

- **app_test.dart**
  - Full app launch
  - Tab navigation flow
  - End-to-end scenarios

## Running Tests

### Run All Unit Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/services/annotation_service_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

To view coverage report (requires lcov):

```bash
# macOS
brew install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open report
open coverage/html/index.html
```

### Run Integration Tests

```bash
# For connected device
flutter test integration_test/app_test.dart

# For specific device
flutter test integration_test/app_test.dart -d macos
flutter test integration_test/app_test.dart -d android
flutter test integration_test/app_test.dart -d ios
```

## Test Coverage Areas

### ✅ Covered

1. **Annotation Service**
   - Drawing stroke serialization
   - JSON conversion
   - Type definitions

2. **Database Models**
   - Model creation
   - Field validation
   - Copy operations

3. **Widget Rendering**
   - DrawingCanvas
   - PdfCard
   - HomeScreen navigation

4. **File Operations**
   - PDF extension validation
   - Syncthing temp file detection

5. **Service Patterns**
   - Singleton consistency
   - Stream availability

### 🔄 Partial Coverage

These areas have basic tests but would benefit from more comprehensive coverage with mocking:

1. **PDF Service**
   - Import functionality
   - Library scanning
   - File handling

2. **SetList Service**
   - CRUD operations
   - Document management
   - Reordering

3. **File Watcher Service**
   - Watch lifecycle
   - Event handling
   - Path management

### ⚠️ Future Testing Needs

These areas require additional test infrastructure (mocks, test databases, etc.):

1. **Database Operations**
   - CRUD operations with real database
   - Migration testing
   - Transaction handling

2. **PDF Viewing**
   - Page rendering
   - Zoom/pan gestures
   - Settings persistence

3. **Annotation Drawing**
   - Gesture capture
   - Stroke creation
   - Layer management

4. **Set List Performance**
   - Document navigation
   - Performance mode UI
   - State persistence

5. **Syncthing Integration**
   - File sync detection
   - Database reload
   - Conflict handling

## Writing New Tests

### Test File Location

- Unit tests for services: `test/services/`
- Unit tests for models: `test/models/`
- Widget tests: `test/widgets/` or `test/screens/`
- Integration tests: `integration_test/`

### Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/path/to/component.dart';

void main() {
  group('ComponentName', () {
    late ComponentType component;

    setUp(() {
      // Initialize before each test
      component = ComponentType();
    });

    tearDown(() {
      // Clean up after each test
    });

    test('should do something', () {
      // Arrange
      final input = 'test';

      // Act
      final result = component.doSomething(input);

      // Assert
      expect(result, equals('expected'));
    });
  });
}
```

### Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feuillet/widgets/my_widget.dart';

void main() {
  testWidgets('MyWidget displays correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyWidget(),
        ),
      ),
    );

    expect(find.byType(MyWidget), findsOneWidget);
    expect(find.text('Expected Text'), findsOneWidget);
  });
}
```

## Continuous Integration

To run tests in CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: flutter test --coverage

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    files: coverage/lcov.info
```

## Best Practices

1. **Isolation**: Each test should be independent and not rely on other tests
2. **Clarity**: Test names should clearly describe what is being tested
3. **Arrange-Act-Assert**: Structure tests with clear setup, execution, and verification
4. **Mock External Dependencies**: Use mocks for database, file system, and network
5. **Test Edge Cases**: Include tests for boundary conditions and error scenarios
6. **Keep Tests Fast**: Unit tests should run quickly; reserve longer tests for integration

## Mocking Strategy

For comprehensive testing, you'll need to mock:

- **Database**: Use in-memory database or mock Drift queries
- **File System**: Use `package:file` with MemoryFileSystem
- **File Watcher**: Create mock event streams
- **PDF Rendering**: Mock pdfx operations
- **Platform Channels**: Mock path_provider and file_picker

Example mock setup:

```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AppDatabase, PdfService])
void main() {
  late MockAppDatabase mockDatabase;

  setUp(() {
    mockDatabase = MockAppDatabase();
  });

  test('with mocked database', () {
    when(mockDatabase.getAllDocuments())
        .thenAnswer((_) async => []);

    // Test code using mockDatabase
  });
}
```

## Test Metrics

Track these metrics to ensure good test coverage:

- **Line Coverage**: Aim for >80%
- **Branch Coverage**: Aim for >70%
- **Test Execution Time**: Keep under 30 seconds for unit tests
- **Test Count**: Balance between thoroughness and maintainability
- **Test Stability**: Minimize flaky tests

## Troubleshooting

### Tests Fail to Initialize

If tests fail due to service initialization:

```dart
TestWidgetsFlutterBinding.ensureInitialized();
```

### Path Provider Issues

Mock path provider in tests:

```dart
setUpAll(() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '/test/path';
      },
    );
});
```

### Database Issues

Use `flutter test --update-goldens` for widget snapshot tests, or create in-memory databases for testing.

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Widget Test Introduction](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Mockito for Dart](https://pub.dev/packages/mockito)
