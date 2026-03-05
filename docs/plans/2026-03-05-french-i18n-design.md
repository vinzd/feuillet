# French i18n Design

## Goal

Add French translations to Feuillet using Flutter's built-in localization system. The app follows device locale, defaulting to English.

## Approach

Use `flutter_localizations` + `gen-l10n` with ARB files. No third-party i18n packages.

## Setup

1. Add `flutter_localizations` SDK dependency in `pubspec.yaml`
2. Set `generate: true` in `pubspec.yaml` flutter section
3. Create `l10n.yaml` at project root with `nullable-getter: false`
4. Create `lib/l10n/app_en.arb` (source of truth) and `lib/l10n/app_fr.arb`
5. Configure `MaterialApp` in `main.dart` with `localizationsDelegates` and `supportedLocales`

## String Access

Add a `BuildContext` extension for concise access:

```dart
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

Usage: `context.l10n.importPdfs`

## ARB Conventions

- camelCase keys grouped by screen/widget
- Plurals use ICU syntax: `"{count, plural, =1{1 document} other{{count} documents}}"`
- Parameterized strings use named placeholders with `@` metadata
- ~100 strings to extract across all screens and widgets

## Migration

Replace every hardcoded string with `context.l10n.keyName`. No behavioral changes.

## Files Affected

- `pubspec.yaml` — dependencies and generate flag
- `l10n.yaml` — new config file
- `lib/l10n/app_en.arb` — new English strings
- `lib/l10n/app_fr.arb` — new French translations
- `lib/l10n/l10n_extension.dart` — BuildContext extension
- `lib/main.dart` — localization delegates
- All files in `lib/screens/` and `lib/widgets/` — string replacement
