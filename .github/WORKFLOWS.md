# GitHub Workflows Documentation

This document describes all GitHub Actions workflows in this repository.

## Overview

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| CI | `ci.yml` | Push/PR to main/develop | Test & analyze code |
| Build All Platforms | `build.yml` | Manual or tags | Build for all platforms |
| Release | `release.yml` | Version tags | Create releases |
| Deploy to Pages | `deploy-pages.yml` | Push to main | Deploy web to GitHub Pages |

## Workflow Details

### 1. CI Workflow (`ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

**Jobs:**
1. **Analyze & Test**
   - Format verification
   - Static analysis with `flutter analyze`
   - Database code generation
   - Run all tests with coverage
   - Upload coverage to Codecov

2. **Build Web**
   - Generate database code
   - Compile drift worker
   - Build web release
   - Upload web artifact (7-day retention)

**Status:** Must pass before merging PRs

### 2. Build All Platforms (`build.yml`)

**Triggers:**
- Manual workflow dispatch
- Version tags (`v*`)

**Jobs:**

1. **Build Android**
   - Runs on: Ubuntu
   - Builds: Release APK
   - Output: `app-release.apk`
   - Retention: 30 days

2. **Build macOS**
   - Runs on: macOS
   - Builds: Release .app
   - Output: `Feuillet-macOS.zip`
   - Retention: 30 days

3. **Build iOS**
   - Runs on: macOS
   - Builds: Release .app (no codesign)
   - Output: `Feuillet-iOS.zip`
   - Retention: 30 days
   - Note: Requires signing before installation

4. **Build Web**
   - Runs on: Ubuntu
   - Builds: Release web bundle
   - Output: `Feuillet-Web.zip`
   - Retention: 30 days

### 3. Release Workflow (`release.yml`)

**Triggers:**
- Version tags matching `v*.*.*` (e.g., `v1.0.0`)

**Process:**
1. Creates a GitHub release with the tag
2. Builds for all platforms in parallel
3. Uploads all artifacts to the release

**Artifacts:**
- `app-release.apk` - Android APK
- `Feuillet-macOS.zip` - macOS app bundle
- `Feuillet-iOS.zip` - iOS app (needs signing)
- `Feuillet-Web.zip` - Web build

**Usage:**
```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

### 4. Deploy to GitHub Pages (`deploy-pages.yml`)

**Triggers:**
- Push to `main` branch
- Manual workflow dispatch

**Process:**
1. Builds web version with correct base-href
2. Copies web worker files
3. Deploys to GitHub Pages

**Setup Required:**
1. Enable GitHub Pages in repository settings
2. Set source to "GitHub Actions"

**Result:**
- Web app accessible at: `https://YOUR_USERNAME.github.io/feuillet/`

## Secrets Configuration

### Optional Secrets

| Secret | Purpose | Required |
|--------|---------|----------|
| `CODECOV_TOKEN` | Upload test coverage | No |

### Future Secrets (if needed)

| Secret | Purpose | When Needed |
|--------|---------|-------------|
| `ANDROID_KEYSTORE` | Sign Android releases | For Play Store |
| `IOS_CERTIFICATE` | Sign iOS releases | For App Store |

## Local Testing

Test workflows locally before pushing:

```bash
# Install act (https://github.com/nektos/act)
brew install act

# Test CI workflow
act -j analyze

# Test build workflow
act workflow_dispatch -W .github/workflows/build.yml
```

## Maintenance

### Updating Flutter Version

Update in all workflow files:
```yaml
uses: subosito/flutter-action@v2
with:
  flutter-version: '3.38.8'  # Update this version
```

### Disabling a Workflow

Add to workflow file:
```yaml
on:
  workflow_dispatch:  # Manual only
```

Or delete the workflow file.

### Dependabot Updates

Dependabot automatically updates:
- Flutter/Dart packages (`pubspec.yaml`)
- GitHub Actions versions (`.github/workflows/*.yml`)

Configuration: `.github/dependabot.yml`

## Troubleshooting

### CI Failing on Format

Run locally:
```bash
make format
git add -u
git commit -m "style: format code"
```

### Build Failing on Database

Regenerate database code:
```bash
make db-gen
git add lib/models/database.g.dart
git commit -m "chore: regenerate database code"
```

### Web Worker Missing

Ensure workflow includes:
```yaml
- name: Compile drift worker
  run: dart compile js -O4 web/drift_worker.dart -o web/drift_worker.js

- name: Copy web worker files
  run: cp -f web/sqlite3.wasm web/drift_worker.js build/web/
```

### Artifact Upload Failing

Check:
1. Artifact path is correct
2. File exists after build
3. Retention days ≤ 90

## Best Practices

1. **Always test locally first**
   ```bash
   make analyze
   make test
   make build-web
   ```

2. **Use conventional commits**
   - CI recognizes: `feat:`, `fix:`, `docs:`, etc.

3. **Keep workflows DRY**
   - Reuse steps with composite actions
   - Use matrix strategy for similar jobs

4. **Monitor workflow runs**
   - Check Actions tab regularly
   - Fix failing workflows promptly

5. **Update dependencies**
   - Review Dependabot PRs weekly
   - Test updates before merging

## Resources

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
