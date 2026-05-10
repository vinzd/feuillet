// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get library => 'Library';

  @override
  String get setLists => 'Set Lists';

  @override
  String get cancelSelection => 'Cancel selection';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get sortOrder => 'Sort order';

  @override
  String get syncLibrary => 'Sync library';

  @override
  String get settings => 'Settings';

  @override
  String get importPdfs => 'Import PDFs';

  @override
  String get searchPdfsHint => 'Search PDFs...';

  @override
  String nSelected(int count) {
    return '$count selected';
  }

  @override
  String get addToSetList => 'Add to Set List';

  @override
  String get export => 'Export';

  @override
  String get delete => 'Delete';

  @override
  String get noPdfsInLibrary => 'No PDFs in library';

  @override
  String get noPdfsMatchSearch => 'No PDFs match your search';

  @override
  String importingProgress(int current, int total) {
    return 'Importing $current of $total...';
  }

  @override
  String importedCountOfTotal(int successCount, int totalCount) {
    return 'Imported $successCount of $totalCount PDFs';
  }

  @override
  String importedPdfs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count PDFs',
      one: 'Imported 1 PDF',
    );
    return '$_temp0';
  }

  @override
  String failedToImportPdfs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Failed to import $count PDFs',
      one: 'Failed to import 1 PDF',
    );
    return '$_temp0';
  }

  @override
  String addedAndSkipped(int addedCount, int skippedCount) {
    return 'Added $addedCount, skipped $skippedCount (already in set list)';
  }

  @override
  String get allSelectedAlreadyInSetList =>
      'All selected documents already in set list';

  @override
  String addedDocumentsToSetList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count documents to set list',
      one: 'Added 1 document to set list',
    );
    return '$_temp0';
  }

  @override
  String get details => 'Details';

  @override
  String get importFailures => 'Import Failures';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get ok => 'OK';

  @override
  String get deleteDocuments => 'Delete Documents';

  @override
  String deleteDocumentsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Are you sure you want to delete $count documents?',
      one: 'Are you sure you want to delete 1 document?',
    );
    return '$_temp0';
  }

  @override
  String get alsoDeleteFromDisk => 'Also delete PDF files from disk';

  @override
  String get cancel => 'Cancel';

  @override
  String deletedDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count documents',
      one: 'Deleted 1 document',
    );
    return '$_temp0';
  }

  @override
  String get exporting => 'Exporting...';

  @override
  String get exportComplete => 'Export Complete';

  @override
  String documentNOfTotal(int index, int total) {
    return 'Document $index of $total';
  }

  @override
  String pageNOfTotal(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String exportedSuccessFailCount(int successCount, int failCount) {
    return 'Exported $successCount, failed $failCount';
  }

  @override
  String exportedDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported $count documents',
      one: 'Exported 1 document',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Done';

  @override
  String get viewMode => 'View mode';

  @override
  String get annotations => 'Annotations';

  @override
  String get displaySettings => 'Display settings';

  @override
  String get exportImage => 'Export image';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get failedToLoadDocument =>
      'Failed to load document. Please try again.';

  @override
  String get exportingImage => 'Exporting image...';

  @override
  String get webExportNotSupported => 'Web export not yet supported for images';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get selectAnnotationLayers => 'Select annotation layers to include:';

  @override
  String get noAnnotationLayersFound => 'No annotation layers found.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get librarySection => 'Library';

  @override
  String get pdfDirectory => 'PDF Directory';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get changeDirectory => 'Change directory';

  @override
  String get customDirectory => 'Custom directory';

  @override
  String get resetToDefaultTitle => 'Reset to Default';

  @override
  String get resetToDefaultMessage =>
      'This will reset the PDF directory to the default location. Your existing PDFs will remain in their current location.';

  @override
  String get reset => 'Reset';

  @override
  String pdfDirectoryUpdated(String path) {
    return 'PDF directory updated to: $path';
  }

  @override
  String errorUpdatingDirectory(String error) {
    return 'Error updating directory: $error';
  }

  @override
  String get resetToDefaultPdfDirectory => 'Reset to default PDF directory';

  @override
  String errorResettingDirectory(String error) {
    return 'Error resetting directory: $error';
  }

  @override
  String get customDirectoryNotAvailableOnWeb =>
      'Custom PDF directory is not available on web.';

  @override
  String get aboutSection => 'About';

  @override
  String get version => 'Version';

  @override
  String get loading => 'Loading...';

  @override
  String get unknown => 'Unknown';

  @override
  String get newSetList => 'New Set List';

  @override
  String get name => 'Name';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get create => 'Create';

  @override
  String get deleteSetList => 'Delete Set List';

  @override
  String deleteSetListConfirmation(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get renameSetList => 'Rename Set List';

  @override
  String get rename => 'Rename';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get setListDuplicated => 'Set list duplicated';

  @override
  String errorLoadingSetLists(String error) {
    return 'Error loading set lists: $error';
  }

  @override
  String get addDocumentsToStartPerformance =>
      'Add documents to start performance mode';

  @override
  String get startPerformance => 'Start performance';

  @override
  String get noSetListsYet => 'No set lists yet';

  @override
  String get createSetList => 'Create Set List';

  @override
  String get noDocuments => 'No documents';

  @override
  String get setList => 'Set List';

  @override
  String get setListNotFound => 'Set list not found';

  @override
  String get noDocumentsInSetList => 'No documents in this set list';

  @override
  String get addDocuments => 'Add Documents';

  @override
  String get allDocumentsAlreadyInSetList =>
      'All documents are already in this set list';

  @override
  String get searchDocumentsHint => 'Search documents...';

  @override
  String nPages(int count) {
    return '$count pages';
  }

  @override
  String addCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get view => 'View';

  @override
  String get remove => 'Remove';

  @override
  String get enterLabelHint => 'Enter label...';

  @override
  String get addLabel => 'Add label';

  @override
  String get documentsInSetList => 'Documents in Set List';

  @override
  String pagesCount(int count) {
    return '$count pages';
  }

  @override
  String get documentList => 'Document list';

  @override
  String get documentNotFound => 'Document Not Found';

  @override
  String get documentNotFoundMessage => 'This document could not be found.';

  @override
  String get backToLibrary => 'Back to Library';

  @override
  String get error => 'Error';

  @override
  String errorLoadingDocument(String error) {
    return 'Error loading document: $error';
  }

  @override
  String get setListNotFoundTitle => 'Set List Not Found';

  @override
  String get setListNotFoundMessage => 'This set list could not be found.';

  @override
  String get backToSetLists => 'Back to Set Lists';

  @override
  String get setListHasNoDocuments => 'This set list has no documents.';

  @override
  String get editSetList => 'Edit Set List';

  @override
  String errorLoadingSetList(String error) {
    return 'Error loading set list: $error';
  }

  @override
  String get brightness => 'Brightness';

  @override
  String get contrast => 'Contrast';

  @override
  String get resetToDefaults => 'Reset to defaults';

  @override
  String get displaySettingsTitle => 'Display Settings';

  @override
  String get exportPdfTitle => 'Export PDF';

  @override
  String get selectLayersToInclude => 'Select layers to include:';

  @override
  String exportingPageProgress(int current, int total) {
    return 'Exporting page $current of $total...';
  }

  @override
  String get pleaseSelectAtLeastOneLayer => 'Please select at least one layer';

  @override
  String get pdfDownloaded => 'PDF downloaded';

  @override
  String get hidden => 'Hidden';

  @override
  String layersSelected(int count) {
    return '$count layer(s) selected';
  }

  @override
  String get close => 'Close';

  @override
  String get pen => 'Pen';

  @override
  String get highlighter => 'Highlighter';

  @override
  String get eraser => 'Eraser';

  @override
  String get newLayer => 'New layer';

  @override
  String get layers => 'Layers';

  @override
  String get noLayers => 'No layers';

  @override
  String get hideLayer => 'Hide layer';

  @override
  String get showLayer => 'Show layer';

  @override
  String get cannotHideActiveLayer => 'Cannot hide active layer';

  @override
  String get deleteLayer => 'Delete Layer';

  @override
  String deleteLayerConfirmation(String name) {
    return 'Are you sure you want to delete \"$name\"? This will delete all annotations on this layer.';
  }

  @override
  String get renameLayer => 'Rename Layer';

  @override
  String get layerName => 'Layer name';

  @override
  String get confirm => 'Confirm';

  @override
  String get createNewSetList => 'Create new set list';

  @override
  String get noSetListsYetCreateAbove => 'No set lists yet. Create one above.';

  @override
  String get add => 'Add';

  @override
  String get previousDocument => 'Previous document';

  @override
  String get nextDocument => 'Next document';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String pagesRange(int start, int end, int total) {
    return 'Pages $start-$end of $total';
  }

  @override
  String pageSingle(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String documentNOfTotalBottom(int index, int total) {
    return 'Document $index of $total';
  }

  @override
  String errorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get failedToRenderPage => 'Failed to render page';

  @override
  String get failedToLoadDocumentGeneric => 'Failed to load document';

  @override
  String errorLoadingLibrary(String error) {
    return 'Error loading library: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByDateAdded => 'Date added';

  @override
  String get sortByFileSize => 'File size';

  @override
  String get sortByPageCount => 'Page count';

  @override
  String get orDragAndDropHint => 'or drag and drop PDF files here';

  @override
  String get manageLabels => 'Manage Labels';

  @override
  String get manageLabelsSubtitle => 'Rename, recolor, or delete labels';

  @override
  String get noLabelsYet => 'No labels yet';

  @override
  String get changeLabelColor => 'Change color';

  @override
  String get pickAColor => 'Pick a color';

  @override
  String get renameLabelTitle => 'Rename Label';

  @override
  String get deleteLabelTitle => 'Delete Label';

  @override
  String deleteLabelConfirmation(String name) {
    return 'Delete \"$name\"? This removes it from all documents.';
  }

  @override
  String get label => 'Label';

  @override
  String get labels => 'Labels';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get renameDocument => 'Rename';

  @override
  String get renameDocumentTitle => 'Rename Document';

  @override
  String get documentRenamed => 'Document renamed';

  @override
  String get renameFailedAlreadyExists =>
      'A file with that name already exists';

  @override
  String get renameFailedGeneric => 'Failed to rename document';

  @override
  String get addLabels => 'Add Labels';

  @override
  String get newLabelName => 'New label name';

  @override
  String get apply => 'Apply';

  @override
  String get createNewLabel => 'Create new label';
}
