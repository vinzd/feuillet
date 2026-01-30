# Contributing to Feuillet

Thank you for your interest in contributing to Feuillet! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the project and community

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/feuillet.git
   cd feuillet
   ```
3. **Set up the project**:
   ```bash
   make setup
   ```
   This will install dependencies, generate code, and install git hooks (including a pre-commit hook that automatically checks formatting).

4. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Git Hooks

The project uses a pre-commit hook to ensure code is properly formatted before committing:
- **Automatic formatting check**: Runs `dart format` on all staged files
- **Auto-format on failure**: If formatting issues are detected, files are automatically formatted
- **Manual review required**: You'll need to review and re-add the formatted files before committing

To install or reinstall hooks:
```bash
make install-hooks
```

### Before Making Changes

1. Make sure you're on the latest `main` branch:
   ```bash
   git checkout main
   git pull origin main
   ```

2. Create a feature branch:
   ```bash
   git checkout -b feature/descriptive-name
   ```

### Making Changes

1. **Write code** following the existing style
2. **Add tests** for new functionality
3. **Update documentation** if needed
4. **Run quality checks**:
   ```bash
   make format    # Format code
   make analyze   # Run static analysis
   make test      # Run all tests
   ```

### Commit Guidelines

Use clear, descriptive commit messages following conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

**Examples:**
```
feat(annotations): add text annotation tool
fix(pdf): resolve page navigation issue
docs(readme): update installation instructions
```

### Submitting Changes

1. **Push your branch**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a Pull Request** on GitHub with:
   - Clear title describing the change
   - Description of what changed and why
   - Reference to any related issues
   - Screenshots for UI changes

3. **Wait for CI** to pass:
   - All tests must pass
   - Code analysis must pass
   - Build must succeed

4. **Address review feedback** if requested

## Pull Request Checklist

- [ ] Code follows the existing style
- [ ] Tests added/updated and passing
- [ ] Documentation updated if needed
- [ ] Commit messages follow guidelines
- [ ] CI checks are passing
- [ ] No merge conflicts with `main`
- [ ] Database migrations added if schema changed

## Testing

### Running Tests

```bash
# All tests
make test

# With coverage
make test-coverage

# Specific test file
flutter test test/services/annotation_service_test.dart
```

### Writing Tests

- Place tests in `test/` directory mirroring `lib/` structure
- Test file naming: `feature_name_test.dart`
- Use descriptive test names
- Follow AAA pattern: Arrange, Act, Assert

Example:
```dart
test('should add annotation to layer', () {
  // Arrange
  final layer = AnnotationLayer(id: 1, name: 'Layer 1');

  // Act
  final result = annotationService.addToLayer(layer, annotation);

  // Assert
  expect(result, isTrue);
});
```

## Code Style

### Dart Style

- Use `dart format` (included in `make format`)
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Maximum line length: 120 characters
- Use trailing commas for better diffs

### Documentation

- Document public APIs with doc comments (`///`)
- Use clear, concise descriptions
- Include examples for complex functionality

Example:
```dart
/// Adds a new annotation to the specified layer.
///
/// Returns the ID of the created annotation or null if failed.
///
/// Example:
/// ```dart
/// final id = await service.addAnnotation(layerId, annotation);
/// ```
Future<int?> addAnnotation(int layerId, Annotation annotation) async {
  // ...
}
```

## Database Changes

When modifying the database schema:

1. **Update schema** in `lib/models/database.dart`
2. **Increment `schemaVersion`**
3. **Add migration** in `onUpgrade`:
   ```dart
   if (from == 1) {
     await m.addColumn(table, table.newColumn);
   }
   ```
4. **Regenerate code**:
   ```bash
   make db-gen
   ```
5. **Test migration** on existing database
6. **Document changes** in PR description

## Platform-Specific Notes

### Web Development

- Web is for development iteration only
- Test native features on actual platforms
- Don't rely on file system operations on web
- Ensure web worker compiles: `make web-worker`

### Native Platforms

- Test on real devices when possible
- Consider platform-specific behavior
- Test Syncthing integration on native platforms

## Getting Help

- **Issues**: Open an issue for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Check [CLAUDE.md](CLAUDE.md) for architecture details

## Review Process

1. Automated CI checks must pass
2. At least one maintainer review required
3. Address all review comments
4. Maintainer will merge when approved

## Release Process

Releases are automated via GitHub Actions:

1. Update `CHANGELOG.md`
2. Create and push a version tag:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```
3. GitHub Actions will build and create a release

## Questions?

If you have questions not covered here, feel free to:
- Open a discussion on GitHub
- Comment on related issues
- Ask in your pull request

Thank you for contributing! 🎉
