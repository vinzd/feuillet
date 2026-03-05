# French i18n Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add French translations to Feuillet using Flutter's built-in localization, following device locale with English default.

**Architecture:** Use `flutter_localizations` + `gen-l10n` with ARB files. Create a `BuildContext` extension for concise access (`context.l10n.key`). Extract all ~100 hardcoded strings from screens and widgets into ARB files with English and French translations.

**Tech Stack:** Flutter `flutter_localizations`, `intl` (already installed), ARB files, `gen-l10n` code generation.

---

### Task 1: Configure i18n infrastructure

**Files:**
- Modify: `pubspec.yaml`
- Create: `l10n.yaml`

**Step 1: Add flutter_localizations dependency and generate flag to pubspec.yaml**

In `pubspec.yaml`, add `flutter_localizations` under dependencies (after the existing `flutter` SDK dependency):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
```

And add `generate: true` inside the `flutter:` section:

```yaml
flutter:
  generate: true
  uses-material-design: true
```

**Step 2: Create l10n.yaml at project root**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

**Step 3: Run flutter gen-l10n to verify config**

Run: `flutter gen-l10n`
Expected: Error about missing ARB files (this is fine, we'll create them in the next task)

**Step 4: Commit**

```bash
git add pubspec.yaml l10n.yaml
git commit -m "chore: configure i18n infrastructure with flutter_localizations"
```

---

### Task 2: Create ARB files with all English strings

**Files:**
- Create: `lib/l10n/app_en.arb`

**Step 1: Create the English ARB file**

Create `lib/l10n/app_en.arb` with all extracted strings. Use camelCase keys grouped by screen/widget. Use ICU plural syntax for count-dependent strings and named placeholders for parameterized strings.

```json
{
  "@@locale": "en",

  "library": "Library",
  "setLists": "Set Lists",

  "cancelSelection": "Cancel selection",
  "listView": "List view",
  "gridView": "Grid view",
  "sortOrder": "Sort order",
  "syncLibrary": "Sync library",
  "settings": "Settings",
  "importPdfs": "Import PDFs",
  "searchPdfsHint": "Search PDFs...",
  "nSelected": "{count} selected",
  "@nSelected": {
    "placeholders": { "count": {"type": "int"} }
  },
  "addToSetList": "Add to Set List",
  "export": "Export",
  "delete": "Delete",
  "noPdfsInLibrary": "No PDFs in library",
  "noPdfsMatchSearch": "No PDFs match your search",

  "importingProgress": "Importing {current} of {total}...",
  "@importingProgress": {
    "placeholders": { "current": {"type": "int"}, "total": {"type": "int"} }
  },
  "importedCountOfTotal": "Imported {successCount} of {totalCount} PDFs",
  "@importedCountOfTotal": {
    "placeholders": { "successCount": {"type": "int"}, "totalCount": {"type": "int"} }
  },
  "importedPdfs": "{count, plural, =1{Imported 1 PDF} other{Imported {count} PDFs}}",
  "@importedPdfs": {
    "placeholders": { "count": {"type": "int"} }
  },
  "failedToImportPdfs": "{count, plural, =1{Failed to import 1 PDF} other{Failed to import {count} PDFs}}",
  "@failedToImportPdfs": {
    "placeholders": { "count": {"type": "int"} }
  },
  "addedAndSkipped": "Added {addedCount}, skipped {skippedCount} (already in set list)",
  "@addedAndSkipped": {
    "placeholders": { "addedCount": {"type": "int"}, "skippedCount": {"type": "int"} }
  },
  "allSelectedAlreadyInSetList": "All selected documents already in set list",
  "addedDocumentsToSetList": "{count, plural, =1{Added 1 document to set list} other{Added {count} documents to set list}}",
  "@addedDocumentsToSetList": {
    "placeholders": { "count": {"type": "int"} }
  },
  "details": "Details",
  "importFailures": "Import Failures",
  "unknownError": "Unknown error",
  "ok": "OK",

  "deleteDocuments": "Delete Documents",
  "deleteDocumentsConfirmation": "{count, plural, =1{Are you sure you want to delete 1 document?} other{Are you sure you want to delete {count} documents?}}",
  "@deleteDocumentsConfirmation": {
    "placeholders": { "count": {"type": "int"} }
  },
  "alsoDeleteFromDisk": "Also delete PDF files from disk",
  "cancel": "Cancel",
  "deletedDocuments": "{count, plural, =1{Deleted 1 document} other{Deleted {count} documents}}",
  "@deletedDocuments": {
    "placeholders": { "count": {"type": "int"} }
  },

  "exporting": "Exporting...",
  "exportComplete": "Export Complete",
  "documentNOfTotal": "Document {index} of {total}",
  "@documentNOfTotal": {
    "placeholders": { "index": {"type": "int"}, "total": {"type": "int"} }
  },
  "pageNOfTotal": "Page {current} of {total}",
  "@pageNOfTotal": {
    "placeholders": { "current": {"type": "int"}, "total": {"type": "int"} }
  },
  "exportedSuccessFailCount": "Exported {successCount}, failed {failCount}",
  "@exportedSuccessFailCount": {
    "placeholders": { "successCount": {"type": "int"}, "failCount": {"type": "int"} }
  },
  "exportedDocuments": "{count, plural, =1{Exported 1 document} other{Exported {count} documents}}",
  "@exportedDocuments": {
    "placeholders": { "count": {"type": "int"} }
  },
  "done": "Done",

  "viewMode": "View mode",
  "annotations": "Annotations",
  "displaySettings": "Display settings",
  "exportImage": "Export image",
  "exportPdf": "Export PDF",
  "failedToLoadDocument": "Failed to load document. Please try again.",
  "exportingImage": "Exporting image...",
  "webExportNotSupported": "Web export not yet supported for images",
  "exportFailed": "Export failed: {error}",
  "@exportFailed": {
    "placeholders": { "error": {"type": "String"} }
  },

  "selectAnnotationLayers": "Select annotation layers to include:",
  "noAnnotationLayersFound": "No annotation layers found.",

  "settingsTitle": "Settings",
  "librarySection": "Library",
  "pdfDirectory": "PDF Directory",
  "resetToDefault": "Reset to default",
  "changeDirectory": "Change directory",
  "customDirectory": "Custom directory",
  "resetToDefaultTitle": "Reset to Default",
  "resetToDefaultMessage": "This will reset the PDF directory to the default location. Your existing PDFs will remain in their current location.",
  "reset": "Reset",
  "pdfDirectoryUpdated": "PDF directory updated to: {path}",
  "@pdfDirectoryUpdated": {
    "placeholders": { "path": {"type": "String"} }
  },
  "errorUpdatingDirectory": "Error updating directory: {error}",
  "@errorUpdatingDirectory": {
    "placeholders": { "error": {"type": "String"} }
  },
  "resetToDefaultPdfDirectory": "Reset to default PDF directory",
  "errorResettingDirectory": "Error resetting directory: {error}",
  "@errorResettingDirectory": {
    "placeholders": { "error": {"type": "String"} }
  },
  "customDirectoryNotAvailableOnWeb": "Custom PDF directory is not available on web.",
  "aboutSection": "About",
  "version": "Version",
  "loading": "Loading...",
  "unknown": "Unknown",

  "newSetList": "New Set List",
  "name": "Name",
  "descriptionOptional": "Description (optional)",
  "create": "Create",
  "deleteSetList": "Delete Set List",
  "deleteSetListConfirmation": "Are you sure you want to delete \"{name}\"?",
  "@deleteSetListConfirmation": {
    "placeholders": { "name": {"type": "String"} }
  },
  "renameSetList": "Rename Set List",
  "rename": "Rename",
  "duplicate": "Duplicate",
  "setListDuplicated": "Set list duplicated",
  "errorLoadingSetLists": "Error loading set lists: {error}",
  "@errorLoadingSetLists": {
    "placeholders": { "error": {"type": "String"} }
  },
  "addDocumentsToStartPerformance": "Add documents to start performance mode",
  "startPerformance": "Start performance",
  "noSetListsYet": "No set lists yet",
  "createSetList": "Create Set List",
  "noDocuments": "No documents",

  "setList": "Set List",
  "setListNotFound": "Set list not found",
  "noDocumentsInSetList": "No documents in this set list",
  "addDocuments": "Add Documents",
  "allDocumentsAlreadyInSetList": "All documents are already in this set list",
  "searchDocumentsHint": "Search documents...",
  "nPages": "{count} pages",
  "@nPages": {
    "placeholders": { "count": {"type": "int"} }
  },
  "addCount": "Add ({count})",
  "@addCount": {
    "placeholders": { "count": {"type": "int"} }
  },
  "view": "View",
  "remove": "Remove",
  "enterLabelHint": "Enter label...",
  "addLabel": "Add label",

  "documentsInSetList": "Documents in Set List",
  "pagesCount": "{count} pages",
  "@pagesCount": {
    "placeholders": { "count": {"type": "int"} }
  },
  "documentList": "Document list",

  "documentNotFound": "Document Not Found",
  "documentNotFoundMessage": "This document could not be found.",
  "backToLibrary": "Back to Library",
  "error": "Error",
  "errorLoadingDocument": "Error loading document: {error}",
  "@errorLoadingDocument": {
    "placeholders": { "error": {"type": "String"} }
  },

  "setListNotFoundTitle": "Set List Not Found",
  "setListNotFoundMessage": "This set list could not be found.",
  "backToSetLists": "Back to Set Lists",
  "setListHasNoDocuments": "This set list has no documents.",
  "editSetList": "Edit Set List",
  "errorLoadingSetList": "Error loading set list: {error}",
  "@errorLoadingSetList": {
    "placeholders": { "error": {"type": "String"} }
  },

  "brightness": "Brightness",
  "contrast": "Contrast",
  "resetToDefaults": "Reset to defaults",

  "exportPdfTitle": "Export PDF",
  "selectLayersToInclude": "Select layers to include:",
  "exportingPageProgress": "Exporting page {current} of {total}...",
  "@exportingPageProgress": {
    "placeholders": { "current": {"type": "int"}, "total": {"type": "int"} }
  },
  "pleaseSelectAtLeastOneLayer": "Please select at least one layer",
  "pdfDownloaded": "PDF downloaded",
  "hidden": "Hidden",
  "layersSelected": "{count} layer(s) selected",
  "@layersSelected": {
    "placeholders": { "count": {"type": "int"} }
  },

  "close": "Close",
  "pen": "Pen",
  "highlighter": "Highlighter",
  "eraser": "Eraser",
  "newLayer": "New layer",
  "layers": "Layers",
  "noLayers": "No layers",
  "hideLayer": "Hide layer",
  "showLayer": "Show layer",
  "cannotHideActiveLayer": "Cannot hide active layer",
  "deleteLayer": "Delete Layer",
  "deleteLayerConfirmation": "Are you sure you want to delete \"{name}\"? This will delete all annotations on this layer.",
  "@deleteLayerConfirmation": {
    "placeholders": { "name": {"type": "String"} }
  },
  "renameLayer": "Rename Layer",
  "layerName": "Layer name",
  "confirm": "Confirm",

  "createNewSetList": "Create new set list",
  "noSetListsYetCreateAbove": "No set lists yet. Create one above.",
  "add": "Add",

  "previousDocument": "Previous document",
  "nextDocument": "Next document",
  "previousPage": "Previous page",
  "nextPage": "Next page",
  "pagesRange": "Pages {start}-{end} of {total}",
  "@pagesRange": {
    "placeholders": { "start": {"type": "int"}, "end": {"type": "int"}, "total": {"type": "int"} }
  },
  "pageSingle": "Page {current} of {total}",
  "@pageSingle": {
    "placeholders": { "current": {"type": "int"}, "total": {"type": "int"} }
  },
  "documentNOfTotalBottom": "Document {index} of {total}",
  "@documentNOfTotalBottom": {
    "placeholders": { "index": {"type": "int"}, "total": {"type": "int"} }
  },

  "errorPrefix": "Error: {error}",
  "@errorPrefix": {
    "placeholders": { "error": {"type": "String"} }
  },
  "failedToRenderPage": "Failed to render page",
  "failedToLoadDocument": "Failed to load document"
}
```

**Step 2: Run code generation**

Run: `flutter gen-l10n`
Expected: Success, generates `lib/l10n/app_localizations.dart` and related files in `.dart_tool/flutter_gen/gen_l10n/`

**Step 3: Commit**

```bash
git add lib/l10n/app_en.arb
git commit -m "feat: add English ARB file with all extracted strings"
```

---

### Task 3: Create French ARB file

**Files:**
- Create: `lib/l10n/app_fr.arb`

**Step 1: Create the French ARB file**

Create `lib/l10n/app_fr.arb` with all French translations. Same keys as English, translated values.

```json
{
  "@@locale": "fr",

  "library": "Bibliothèque",
  "setLists": "Listes",

  "cancelSelection": "Annuler la sélection",
  "listView": "Vue en liste",
  "gridView": "Vue en grille",
  "sortOrder": "Ordre de tri",
  "syncLibrary": "Synchroniser la bibliothèque",
  "settings": "Réglages",
  "importPdfs": "Importer des PDF",
  "searchPdfsHint": "Rechercher des PDF...",
  "nSelected": "{count} sélectionné(s)",
  "addToSetList": "Ajouter à une liste",
  "export": "Exporter",
  "delete": "Supprimer",
  "noPdfsInLibrary": "Aucun PDF dans la bibliothèque",
  "noPdfsMatchSearch": "Aucun PDF ne correspond à la recherche",

  "importingProgress": "Import de {current} sur {total}...",
  "importedCountOfTotal": "{successCount} sur {totalCount} PDF importés",
  "importedPdfs": "{count, plural, =1{1 PDF importé} other{{count} PDF importés}}",
  "failedToImportPdfs": "{count, plural, =1{Échec de l'import d'1 PDF} other{Échec de l'import de {count} PDF}}",
  "addedAndSkipped": "{addedCount} ajouté(s), {skippedCount} ignoré(s) (déjà dans la liste)",
  "allSelectedAlreadyInSetList": "Tous les documents sélectionnés sont déjà dans la liste",
  "addedDocumentsToSetList": "{count, plural, =1{1 document ajouté à la liste} other{{count} documents ajoutés à la liste}}",
  "details": "Détails",
  "importFailures": "Échecs d'import",
  "unknownError": "Erreur inconnue",
  "ok": "OK",

  "deleteDocuments": "Supprimer les documents",
  "deleteDocumentsConfirmation": "{count, plural, =1{Voulez-vous vraiment supprimer 1 document ?} other{Voulez-vous vraiment supprimer {count} documents ?}}",
  "alsoDeleteFromDisk": "Supprimer aussi les fichiers PDF du disque",
  "cancel": "Annuler",
  "deletedDocuments": "{count, plural, =1{1 document supprimé} other{{count} documents supprimés}}",

  "exporting": "Export en cours...",
  "exportComplete": "Export terminé",
  "documentNOfTotal": "Document {index} sur {total}",
  "pageNOfTotal": "Page {current} sur {total}",
  "exportedSuccessFailCount": "{successCount} exporté(s), {failCount} échoué(s)",
  "exportedDocuments": "{count, plural, =1{1 document exporté} other{{count} documents exportés}}",
  "done": "Terminé",

  "viewMode": "Mode d'affichage",
  "annotations": "Annotations",
  "displaySettings": "Réglages d'affichage",
  "exportImage": "Exporter l'image",
  "exportPdf": "Exporter le PDF",
  "failedToLoadDocument": "Échec du chargement du document. Veuillez réessayer.",
  "exportingImage": "Export de l'image...",
  "webExportNotSupported": "L'export d'images n'est pas encore disponible sur le web",
  "exportFailed": "Échec de l'export : {error}",

  "selectAnnotationLayers": "Sélectionner les calques d'annotations à inclure :",
  "noAnnotationLayersFound": "Aucun calque d'annotations trouvé.",

  "settingsTitle": "Réglages",
  "librarySection": "Bibliothèque",
  "pdfDirectory": "Dossier PDF",
  "resetToDefault": "Réinitialiser par défaut",
  "changeDirectory": "Changer de dossier",
  "customDirectory": "Dossier personnalisé",
  "resetToDefaultTitle": "Réinitialiser par défaut",
  "resetToDefaultMessage": "Le dossier PDF sera réinitialisé à l'emplacement par défaut. Vos PDF existants resteront à leur emplacement actuel.",
  "reset": "Réinitialiser",
  "pdfDirectoryUpdated": "Dossier PDF mis à jour : {path}",
  "errorUpdatingDirectory": "Erreur de mise à jour du dossier : {error}",
  "resetToDefaultPdfDirectory": "Dossier PDF réinitialisé par défaut",
  "errorResettingDirectory": "Erreur de réinitialisation du dossier : {error}",
  "customDirectoryNotAvailableOnWeb": "Le dossier PDF personnalisé n'est pas disponible sur le web.",
  "aboutSection": "À propos",
  "version": "Version",
  "loading": "Chargement...",
  "unknown": "Inconnu",

  "newSetList": "Nouvelle liste",
  "name": "Nom",
  "descriptionOptional": "Description (facultatif)",
  "create": "Créer",
  "deleteSetList": "Supprimer la liste",
  "deleteSetListConfirmation": "Voulez-vous vraiment supprimer « {name} » ?",
  "renameSetList": "Renommer la liste",
  "rename": "Renommer",
  "duplicate": "Dupliquer",
  "setListDuplicated": "Liste dupliquée",
  "errorLoadingSetLists": "Erreur de chargement des listes : {error}",
  "addDocumentsToStartPerformance": "Ajoutez des documents pour démarrer le mode performance",
  "startPerformance": "Démarrer la performance",
  "noSetListsYet": "Aucune liste pour le moment",
  "createSetList": "Créer une liste",
  "noDocuments": "Aucun document",

  "setList": "Liste",
  "setListNotFound": "Liste introuvable",
  "noDocumentsInSetList": "Aucun document dans cette liste",
  "addDocuments": "Ajouter des documents",
  "allDocumentsAlreadyInSetList": "Tous les documents sont déjà dans cette liste",
  "searchDocumentsHint": "Rechercher des documents...",
  "nPages": "{count} pages",
  "addCount": "Ajouter ({count})",
  "view": "Voir",
  "remove": "Retirer",
  "enterLabelHint": "Saisir un libellé...",
  "addLabel": "Ajouter un libellé",

  "documentsInSetList": "Documents de la liste",
  "pagesCount": "{count} pages",
  "documentList": "Liste des documents",

  "documentNotFound": "Document introuvable",
  "documentNotFoundMessage": "Ce document est introuvable.",
  "backToLibrary": "Retour à la bibliothèque",
  "error": "Erreur",
  "errorLoadingDocument": "Erreur de chargement du document : {error}",

  "setListNotFoundTitle": "Liste introuvable",
  "setListNotFoundMessage": "Cette liste est introuvable.",
  "backToSetLists": "Retour aux listes",
  "setListHasNoDocuments": "Cette liste ne contient aucun document.",
  "editSetList": "Modifier la liste",
  "errorLoadingSetList": "Erreur de chargement de la liste : {error}",

  "brightness": "Luminosité",
  "contrast": "Contraste",
  "resetToDefaults": "Réinitialiser",

  "exportPdfTitle": "Exporter le PDF",
  "selectLayersToInclude": "Sélectionner les calques à inclure :",
  "exportingPageProgress": "Export de la page {current} sur {total}...",
  "pleaseSelectAtLeastOneLayer": "Veuillez sélectionner au moins un calque",
  "pdfDownloaded": "PDF téléchargé",
  "hidden": "Masqué",
  "layersSelected": "{count} calque(s) sélectionné(s)",

  "close": "Fermer",
  "pen": "Stylo",
  "highlighter": "Surligneur",
  "eraser": "Gomme",
  "newLayer": "Nouveau calque",
  "layers": "Calques",
  "noLayers": "Aucun calque",
  "hideLayer": "Masquer le calque",
  "showLayer": "Afficher le calque",
  "cannotHideActiveLayer": "Impossible de masquer le calque actif",
  "deleteLayer": "Supprimer le calque",
  "deleteLayerConfirmation": "Voulez-vous vraiment supprimer « {name} » ? Toutes les annotations de ce calque seront supprimées.",
  "renameLayer": "Renommer le calque",
  "layerName": "Nom du calque",
  "confirm": "Confirmer",

  "createNewSetList": "Créer une nouvelle liste",
  "noSetListsYetCreateAbove": "Aucune liste. Créez-en une ci-dessus.",
  "add": "Ajouter",

  "previousDocument": "Document précédent",
  "nextDocument": "Document suivant",
  "previousPage": "Page précédente",
  "nextPage": "Page suivante",
  "pagesRange": "Pages {start}-{end} sur {total}",
  "pageSingle": "Page {current} sur {total}",
  "documentNOfTotalBottom": "Document {index} sur {total}",

  "errorPrefix": "Erreur : {error}",
  "failedToRenderPage": "Échec du rendu de la page",
  "failedToLoadDocument": "Échec du chargement du document"
}
```

**Step 2: Run code generation**

Run: `flutter gen-l10n`
Expected: Success, both locales generated

**Step 3: Commit**

```bash
git add lib/l10n/app_fr.arb
git commit -m "feat: add French ARB file with all translations"
```

---

### Task 4: Create l10n extension and wire up MaterialApp

**Files:**
- Create: `lib/l10n/l10n_extension.dart`
- Modify: `lib/main.dart`

**Step 1: Create the BuildContext extension**

Create `lib/l10n/l10n_extension.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

export 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

**Step 2: Wire up localization in MaterialApp**

In `lib/main.dart`, add import:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

Then update `MaterialApp.router(...)` to add:

```dart
MaterialApp.router(
  title: 'Feuillet',
  debugShowCheckedModeBanner: false,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: _buildTheme(Brightness.light),
  darkTheme: _buildTheme(Brightness.dark),
  themeMode: ThemeMode.system,
  routerConfig: router,
),
```

**Step 3: Verify the app runs**

Run: `flutter run -d chrome` (or `make run-web`)
Expected: App launches with English strings (assuming device locale is English)

**Step 4: Commit**

```bash
git add lib/l10n/l10n_extension.dart lib/main.dart
git commit -m "feat: wire up localization delegates in MaterialApp"
```

---

### Task 5: Replace strings in home_screen.dart

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Step 1: Add import and replace strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

Replace hardcoded strings:
- Line 48: `'Library'` → `context.l10n.library`
- Line 53: `'Set Lists'` → `context.l10n.setLists`

Note: `NavigationDestination` uses `label` which is a `String`, not a `Widget`. The `const` keyword must be removed from the `destinations` list since `context.l10n` calls are not const. Move the destinations into the `build` method body.

**Step 2: Verify build**

Run: `flutter analyze`
Expected: No errors

**Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(i18n): translate home screen"
```

---

### Task 6: Replace strings in settings_screen.dart

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Step 1: Add import and replace all strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

Replace all hardcoded strings throughout the file:
- `'Settings'` → `context.l10n.settingsTitle`
- `'Library'` → `context.l10n.librarySection`
- `'PDF Directory'` → `context.l10n.pdfDirectory`
- `'Loading...'` → `context.l10n.loading`
- `'Reset to default'` → `context.l10n.resetToDefault`
- `'Change directory'` → `context.l10n.changeDirectory`
- `'Custom directory'` → `context.l10n.customDirectory`
- `'Reset to Default'` (dialog title) → `context.l10n.resetToDefaultTitle`
- Dialog content text → `context.l10n.resetToDefaultMessage`
- `'Cancel'` → `context.l10n.cancel`
- `'Reset'` → `context.l10n.reset`
- `'PDF directory updated to: $result'` → `context.l10n.pdfDirectoryUpdated(result)`
- `'Error updating directory: $e'` → `context.l10n.errorUpdatingDirectory(e.toString())`
- `'Reset to default PDF directory'` → `context.l10n.resetToDefaultPdfDirectory`
- `'Error resetting directory: $e'` → `context.l10n.errorResettingDirectory(e.toString())`
- `'Custom PDF directory is not available on web.'` → `context.l10n.customDirectoryNotAvailableOnWeb`
- `'About'` → `context.l10n.aboutSection`
- `'Version'` → `context.l10n.version`
- `'Loading...'` (version) → `context.l10n.loading`
- `'Unknown'` → `context.l10n.unknown`

Remove `const` from widgets that now use `context.l10n`.

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat(i18n): translate settings screen"
```

---

### Task 7: Replace strings in setlists_screen.dart

**Files:**
- Modify: `lib/screens/setlists_screen.dart`

**Step 1: Add import and replace all strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

Replace all hardcoded strings:
- `'Set Lists'` → `context.l10n.setLists`
- `'New Set List'` (dialog & FAB) → `context.l10n.newSetList`
- `'Name'` → `context.l10n.name`
- `'Description (optional)'` → `context.l10n.descriptionOptional`
- `'Cancel'` → `context.l10n.cancel`
- `'Create'` → `context.l10n.create`
- `'Delete Set List'` → `context.l10n.deleteSetList`
- `'Are you sure...'` → `context.l10n.deleteSetListConfirmation(setList.name)`
- `'Delete'` → `context.l10n.delete`
- `'Rename Set List'` → `context.l10n.renameSetList`
- `'Rename'` → `context.l10n.rename`
- `'Duplicate'` → `context.l10n.duplicate`
- `'Set list duplicated'` → `context.l10n.setListDuplicated`
- `'Add documents to start performance mode'` → `context.l10n.addDocumentsToStartPerformance`
- `'Start performance'` → `context.l10n.startPerformance`
- `'No set lists yet'` → `context.l10n.noSetListsYet`
- `'Create Set List'` → `context.l10n.createSetList`
- `'No documents'` → `context.l10n.noDocuments`
- `'Error loading set lists: $error'` → `context.l10n.errorLoadingSetLists(error.toString())`

Note: Dialog builders get their own `context` — use the dialog `context` for `l10n` calls inside dialogs.

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/setlists_screen.dart
git commit -m "feat(i18n): translate set lists screen"
```

---

### Task 8: Replace strings in setlist_detail_screen.dart

**Files:**
- Modify: `lib/screens/setlist_detail_screen.dart`

**Step 1: Add import and replace all strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

Replace all hardcoded strings:
- `'Set List'` → `context.l10n.setList`
- `'Set list not found'` → `context.l10n.setListNotFound`
- `'No documents in this set list'` → `context.l10n.noDocumentsInSetList`
- `'Add Documents'` (button, FAB, dialog title) → `context.l10n.addDocuments`
- `'All documents are already in this set list'` → `context.l10n.allDocumentsAlreadyInSetList`
- `'Add documents to start performance mode'` → `context.l10n.addDocumentsToStartPerformance`
- `'Start performance'` → `context.l10n.startPerformance`
- `'Search documents...'` → `context.l10n.searchDocumentsHint`
- `'${doc.pageCount} pages'` → `context.l10n.nPages(doc.pageCount)`
- `'Cancel'` → `context.l10n.cancel`
- `'Add (${_selectedIds.length})'` → `context.l10n.addCount(_selectedIds.length)`
- `'View'` → `context.l10n.view`
- `'Remove'` → `context.l10n.remove`
- `'Enter label...'` → `context.l10n.enterLabelHint`
- `'Add label'` → `context.l10n.addLabel`

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/setlist_detail_screen.dart
git commit -m "feat(i18n): translate set list detail screen"
```

---

### Task 9: Replace strings in document_viewer_screen.dart

**Files:**
- Modify: `lib/screens/document_viewer_screen.dart`

**Step 1: Add import and replace all strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

Replace all hardcoded strings:
- `'View mode'` → `context.l10n.viewMode`
- `'Annotations'` → `context.l10n.annotations`
- `'Display settings'` → `context.l10n.displaySettings`
- `'Export image'` / `'Export PDF'` → `context.l10n.exportImage` / `context.l10n.exportPdf`
- `'Failed to load document. Please try again.'` → `context.l10n.failedToLoadDocument`
- `'Exporting image...'` → `context.l10n.exportingImage`
- `'Web export not yet supported for images'` → `context.l10n.webExportNotSupported`
- `'Export failed: $e'` → `context.l10n.exportFailed(e.toString())`
- `'Export Image'` (dialog) → `context.l10n.exportImage`
- `'Select annotation layers to include:'` → `context.l10n.selectAnnotationLayers`
- `'No annotation layers found.'` → `context.l10n.noAnnotationLayersFound`
- `'Cancel'` → `context.l10n.cancel`
- `'Export'` → `context.l10n.export`

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/document_viewer_screen.dart
git commit -m "feat(i18n): translate document viewer screen"
```

---

### Task 10: Replace strings in setlist_performance_screen.dart

**Files:**
- Modify: `lib/screens/setlist_performance_screen.dart`

**Step 1: Add import and replace all strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

Replace all hardcoded strings:
- `'View mode'` → `context.l10n.viewMode`
- `'Display settings'` → `context.l10n.displaySettings`
- `'Document list'` → `context.l10n.documentList`
- `'Documents in Set List'` → `context.l10n.documentsInSetList`
- `'${doc.pageCount} pages'` → `context.l10n.pagesCount(doc.pageCount)`

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/setlist_performance_screen.dart
git commit -m "feat(i18n): translate set list performance screen"
```

---

### Task 11: Replace strings in library_screen.dart

**Files:**
- Modify: `lib/screens/library_screen.dart`

**Step 1: Add import and replace all strings**

Add import:
```dart
import '../l10n/l10n_extension.dart';
```

This is the largest file. Replace all hardcoded strings throughout. Key replacements:
- All tooltip strings (Cancel selection, List view, Grid view, Sort order, etc.)
- `'Search PDFs...'` → `context.l10n.searchPdfsHint`
- `'${count} selected'` → `context.l10n.nSelected(count)`
- `'Add to Set List'`, `'Export'`, `'Delete'` → respective l10n keys
- `'No PDFs in library'` / `'No PDFs match your search'` → respective l10n keys
- `'Import PDFs'` → `context.l10n.importPdfs`
- Import progress/result strings → parameterized/plural l10n calls
- Delete dialog strings → l10n calls
- Batch export dialog strings → l10n calls

Note: The `_pluralize` helper function can be removed since ICU plural syntax handles this now.

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/library_screen.dart
git commit -m "feat(i18n): translate library screen"
```

---

### Task 12: Replace strings in widget files

**Files:**
- Modify: `lib/widgets/display_settings_panel.dart`
- Modify: `lib/widgets/floating_annotations_panel.dart`
- Modify: `lib/widgets/layer_dialogs.dart`
- Modify: `lib/widgets/setlist_picker_dialog.dart`
- Modify: `lib/widgets/export_pdf_dialog.dart`
- Modify: `lib/widgets/performance_bottom_controls.dart`
- Modify: `lib/widgets/cached_pdf_page.dart`
- Modify: `lib/widgets/cached_pdf_view.dart`

**Step 1: Add imports and replace strings in each widget**

Add to each file:
```dart
import '../l10n/l10n_extension.dart';
```

**display_settings_panel.dart:**
- `'Display Settings'` → `context.l10n.displaySettings`
- `'Brightness'` → `context.l10n.brightness`
- `'Contrast'` → `context.l10n.contrast`
- `'Reset to defaults'` → `context.l10n.resetToDefaults`

**floating_annotations_panel.dart:**
- `'Annotations'` → `context.l10n.annotations`
- `'Close'` → `context.l10n.close`
- `'Pen'` → `context.l10n.pen`
- `'Highlighter'` → `context.l10n.highlighter`
- `'Eraser'` → `context.l10n.eraser`
- `'Layers'` → `context.l10n.layers`
- `'New layer'` → `context.l10n.newLayer`
- `'No layers'` → `context.l10n.noLayers`
- `'Create'` → `context.l10n.create`
- `'Rename'` → `context.l10n.rename`
- `'Delete'` → `context.l10n.delete`
- `'Rename Layer'` → `context.l10n.renameLayer`
- `'Layer name'` → `context.l10n.layerName`
- `'Delete Layer'` → `context.l10n.deleteLayer`
- Delete confirmation message → `context.l10n.deleteLayerConfirmation(layer.name)`
- Layer visibility tooltips → `context.l10n.hideLayer` / `context.l10n.showLayer` / `context.l10n.cannotHideActiveLayer`

**layer_dialogs.dart:**
- `'Cancel'` → Use `AppLocalizations.of(context).cancel` (or pass context.l10n)
- `'Create'` / `'Rename'` → Use l10n equivalents
- `'Cancel'` in confirmation → l10n

Note: `LayerDialogs` is a static helper — the `context` parameter is available, so use `AppLocalizations.of(context)` or the extension.

**setlist_picker_dialog.dart:**
- `'Add to Set List'` → `context.l10n.addToSetList`
- `'Create new set list'` → `context.l10n.createNewSetList`
- `'Name'` → `context.l10n.name`
- `'Description (optional)'` → `context.l10n.descriptionOptional`
- `'No set lists yet. Create one above.'` → `context.l10n.noSetListsYetCreateAbove`
- `'Cancel'` → `context.l10n.cancel`
- `'Add'` → `context.l10n.add`

**export_pdf_dialog.dart:**
- `'Export PDF'` → `context.l10n.exportPdfTitle`
- `'Cancel'` → `context.l10n.cancel`
- `'Export'` → `context.l10n.export`
- `'Exporting page $_exportProgress of $_exportTotal...'` → `context.l10n.exportingPageProgress(_exportProgress, _exportTotal)`
- `'No annotation layers found.'` → `context.l10n.noAnnotationLayersFound`
- `'Select layers to include:'` → `context.l10n.selectLayersToInclude`
- `'Please select at least one layer'` → `context.l10n.pleaseSelectAtLeastOneLayer`
- `'PDF downloaded'` → `context.l10n.pdfDownloaded`
- `'Hidden'` → `context.l10n.hidden`
- `'${_selectedLayerIds.length} layer(s) selected'` → `context.l10n.layersSelected(_selectedLayerIds.length)`

**performance_bottom_controls.dart:**
- `'Previous document'` → l10n (need context — this is a StatelessWidget, context available in build)
- `'Next document'` → `context.l10n.nextDocument`
- `'Previous page'` → `context.l10n.previousPage`
- `'Next page'` → `context.l10n.nextPage`
- `'Document ${currentDocIndex + 1} of $totalDocs'` → `context.l10n.documentNOfTotalBottom(currentDocIndex + 1, totalDocs)`
- Page text logic → use `context.l10n.pagesRange(...)` or `context.l10n.pageSingle(...)`

**cached_pdf_page.dart:**
- `'Error: $_error'` → `context.l10n.errorPrefix(_error!)`
- `'Failed to render page'` → `context.l10n.failedToRenderPage`

**cached_pdf_view.dart:**
- `'Error: $_error'` → `context.l10n.errorPrefix(_error.toString())`
- `'Failed to load document'` → `context.l10n.failedToLoadDocument`

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/widgets/
git commit -m "feat(i18n): translate all widget files"
```

---

### Task 13: Replace strings in wrapper files

**Files:**
- Modify: `lib/screens/wrappers/document_viewer_wrapper.dart`
- Modify: `lib/screens/wrappers/setlist_performance_wrapper.dart`

**Step 1: Add imports and replace strings**

Add to each:
```dart
import '../../l10n/l10n_extension.dart';
```

**document_viewer_wrapper.dart:**
- `'Document Not Found'` → `context.l10n.documentNotFound`
- `'This document could not be found.'` → `context.l10n.documentNotFoundMessage`
- `'Back to Library'` → `context.l10n.backToLibrary`
- `'Error'` → `context.l10n.error`
- `'Error loading document: $error'` → `context.l10n.errorLoadingDocument(error.toString())`

**setlist_performance_wrapper.dart:**
- `'Set List Not Found'` → `context.l10n.setListNotFoundTitle`
- `'This set list could not be found.'` → `context.l10n.setListNotFoundMessage`
- `'Back to Set Lists'` → `context.l10n.backToSetLists`
- `'This set list has no documents.'` → `context.l10n.setListHasNoDocuments`
- `'Edit Set List'` → `context.l10n.editSetList`
- `'Error'` → `context.l10n.error`
- `'Error loading set list: $error'` → `context.l10n.errorLoadingSetList(error.toString())`

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```bash
git add lib/screens/wrappers/
git commit -m "feat(i18n): translate wrapper screens"
```

---

### Task 14: Final verification

**Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No issues

**Step 2: Run tests**

Run: `flutter test`
Expected: All tests pass (tests may need minor updates if they check for specific English strings, but most tests in this codebase are service-level)

**Step 3: Run the app and verify**

Run: `make run-web`
Expected: App displays in English (or French if browser locale is French). All strings display correctly.

**Step 4: Verify French by temporarily changing locale**

In `main.dart`, temporarily add `locale: const Locale('fr')` to `MaterialApp.router` to force French, verify all screens show French text, then remove it.

**Step 5: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address i18n review findings"
```
