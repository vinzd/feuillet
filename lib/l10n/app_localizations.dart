import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @setLists.
  ///
  /// In en, this message translates to:
  /// **'Set Lists'**
  String get setLists;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @sortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get sortOrder;

  /// No description provided for @syncLibrary.
  ///
  /// In en, this message translates to:
  /// **'Sync library'**
  String get syncLibrary;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @importPdfs.
  ///
  /// In en, this message translates to:
  /// **'Import PDFs'**
  String get importPdfs;

  /// No description provided for @searchPdfsHint.
  ///
  /// In en, this message translates to:
  /// **'Search PDFs...'**
  String get searchPdfsHint;

  /// No description provided for @nSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String nSelected(int count);

  /// No description provided for @addToSetList.
  ///
  /// In en, this message translates to:
  /// **'Add to Set List'**
  String get addToSetList;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noPdfsInLibrary.
  ///
  /// In en, this message translates to:
  /// **'No PDFs in library'**
  String get noPdfsInLibrary;

  /// No description provided for @noPdfsMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No PDFs match your search'**
  String get noPdfsMatchSearch;

  /// No description provided for @importingProgress.
  ///
  /// In en, this message translates to:
  /// **'Importing {current} of {total}...'**
  String importingProgress(int current, int total);

  /// No description provided for @importedCountOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Imported {successCount} of {totalCount} PDFs'**
  String importedCountOfTotal(int successCount, int totalCount);

  /// No description provided for @importedPdfs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 PDF} other{Imported {count} PDFs}}'**
  String importedPdfs(int count);

  /// No description provided for @failedToImportPdfs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Failed to import 1 PDF} other{Failed to import {count} PDFs}}'**
  String failedToImportPdfs(int count);

  /// No description provided for @addedAndSkipped.
  ///
  /// In en, this message translates to:
  /// **'Added {addedCount}, skipped {skippedCount} (already in set list)'**
  String addedAndSkipped(int addedCount, int skippedCount);

  /// No description provided for @allSelectedAlreadyInSetList.
  ///
  /// In en, this message translates to:
  /// **'All selected documents already in set list'**
  String get allSelectedAlreadyInSetList;

  /// No description provided for @addedDocumentsToSetList.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 document to set list} other{Added {count} documents to set list}}'**
  String addedDocumentsToSetList(int count);

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @importFailures.
  ///
  /// In en, this message translates to:
  /// **'Import Failures'**
  String get importFailures;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @deleteDocuments.
  ///
  /// In en, this message translates to:
  /// **'Delete Documents'**
  String get deleteDocuments;

  /// No description provided for @deleteDocumentsConfirmation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Are you sure you want to delete 1 document?} other{Are you sure you want to delete {count} documents?}}'**
  String deleteDocumentsConfirmation(int count);

  /// No description provided for @alsoDeleteFromDisk.
  ///
  /// In en, this message translates to:
  /// **'Also delete PDF files from disk'**
  String get alsoDeleteFromDisk;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deletedDocuments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 document} other{Deleted {count} documents}}'**
  String deletedDocuments(int count);

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @exportComplete.
  ///
  /// In en, this message translates to:
  /// **'Export Complete'**
  String get exportComplete;

  /// No description provided for @documentNOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Document {index} of {total}'**
  String documentNOfTotal(int index, int total);

  /// No description provided for @pageNOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageNOfTotal(int current, int total);

  /// No description provided for @exportedSuccessFailCount.
  ///
  /// In en, this message translates to:
  /// **'Exported {successCount}, failed {failCount}'**
  String exportedSuccessFailCount(int successCount, int failCount);

  /// No description provided for @exportedDocuments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Exported 1 document} other{Exported {count} documents}}'**
  String exportedDocuments(int count);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @viewMode.
  ///
  /// In en, this message translates to:
  /// **'View mode'**
  String get viewMode;

  /// No description provided for @annotations.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get annotations;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display settings'**
  String get displaySettings;

  /// No description provided for @exportImage.
  ///
  /// In en, this message translates to:
  /// **'Export image'**
  String get exportImage;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @failedToLoadDocument.
  ///
  /// In en, this message translates to:
  /// **'Failed to load document. Please try again.'**
  String get failedToLoadDocument;

  /// No description provided for @exportingImage.
  ///
  /// In en, this message translates to:
  /// **'Exporting image...'**
  String get exportingImage;

  /// No description provided for @webExportNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Web export not yet supported for images'**
  String get webExportNotSupported;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @selectAnnotationLayers.
  ///
  /// In en, this message translates to:
  /// **'Select annotation layers to include:'**
  String get selectAnnotationLayers;

  /// No description provided for @noAnnotationLayersFound.
  ///
  /// In en, this message translates to:
  /// **'No annotation layers found.'**
  String get noAnnotationLayersFound;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @librarySection.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get librarySection;

  /// No description provided for @pdfDirectory.
  ///
  /// In en, this message translates to:
  /// **'PDF Directory'**
  String get pdfDirectory;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetToDefault;

  /// No description provided for @changeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Change directory'**
  String get changeDirectory;

  /// No description provided for @customDirectory.
  ///
  /// In en, this message translates to:
  /// **'Custom directory'**
  String get customDirectory;

  /// No description provided for @resetToDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefaultTitle;

  /// No description provided for @resetToDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'This will reset the PDF directory to the default location. Your existing PDFs will remain in their current location.'**
  String get resetToDefaultMessage;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @pdfDirectoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'PDF directory updated to: {path}'**
  String pdfDirectoryUpdated(String path);

  /// No description provided for @errorUpdatingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Error updating directory: {error}'**
  String errorUpdatingDirectory(String error);

  /// No description provided for @resetToDefaultPdfDirectory.
  ///
  /// In en, this message translates to:
  /// **'Reset to default PDF directory'**
  String get resetToDefaultPdfDirectory;

  /// No description provided for @errorResettingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Error resetting directory: {error}'**
  String errorResettingDirectory(String error);

  /// No description provided for @customDirectoryNotAvailableOnWeb.
  ///
  /// In en, this message translates to:
  /// **'Custom PDF directory is not available on web.'**
  String get customDirectoryNotAvailableOnWeb;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @newSetList.
  ///
  /// In en, this message translates to:
  /// **'New Set List'**
  String get newSetList;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @deleteSetList.
  ///
  /// In en, this message translates to:
  /// **'Delete Set List'**
  String get deleteSetList;

  /// No description provided for @deleteSetListConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteSetListConfirmation(String name);

  /// No description provided for @renameSetList.
  ///
  /// In en, this message translates to:
  /// **'Rename Set List'**
  String get renameSetList;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @setListDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Set list duplicated'**
  String get setListDuplicated;

  /// No description provided for @errorLoadingSetLists.
  ///
  /// In en, this message translates to:
  /// **'Error loading set lists: {error}'**
  String errorLoadingSetLists(String error);

  /// No description provided for @addDocumentsToStartPerformance.
  ///
  /// In en, this message translates to:
  /// **'Add documents to start performance mode'**
  String get addDocumentsToStartPerformance;

  /// No description provided for @startPerformance.
  ///
  /// In en, this message translates to:
  /// **'Start performance'**
  String get startPerformance;

  /// No description provided for @noSetListsYet.
  ///
  /// In en, this message translates to:
  /// **'No set lists yet'**
  String get noSetListsYet;

  /// No description provided for @createSetList.
  ///
  /// In en, this message translates to:
  /// **'Create Set List'**
  String get createSetList;

  /// No description provided for @noDocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents'**
  String get noDocuments;

  /// No description provided for @setList.
  ///
  /// In en, this message translates to:
  /// **'Set List'**
  String get setList;

  /// No description provided for @setListNotFound.
  ///
  /// In en, this message translates to:
  /// **'Set list not found'**
  String get setListNotFound;

  /// No description provided for @noDocumentsInSetList.
  ///
  /// In en, this message translates to:
  /// **'No documents in this set list'**
  String get noDocumentsInSetList;

  /// No description provided for @addDocuments.
  ///
  /// In en, this message translates to:
  /// **'Add Documents'**
  String get addDocuments;

  /// No description provided for @allDocumentsAlreadyInSetList.
  ///
  /// In en, this message translates to:
  /// **'All documents are already in this set list'**
  String get allDocumentsAlreadyInSetList;

  /// No description provided for @searchDocumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Search documents...'**
  String get searchDocumentsHint;

  /// No description provided for @nPages.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String nPages(int count);

  /// No description provided for @addCount.
  ///
  /// In en, this message translates to:
  /// **'Add ({count})'**
  String addCount(int count);

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @enterLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Enter label...'**
  String get enterLabelHint;

  /// No description provided for @addLabel.
  ///
  /// In en, this message translates to:
  /// **'Add label'**
  String get addLabel;

  /// No description provided for @documentsInSetList.
  ///
  /// In en, this message translates to:
  /// **'Documents in Set List'**
  String get documentsInSetList;

  /// No description provided for @pagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String pagesCount(int count);

  /// No description provided for @documentList.
  ///
  /// In en, this message translates to:
  /// **'Document list'**
  String get documentList;

  /// No description provided for @documentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Document Not Found'**
  String get documentNotFound;

  /// No description provided for @documentNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This document could not be found.'**
  String get documentNotFoundMessage;

  /// No description provided for @backToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Back to Library'**
  String get backToLibrary;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorLoadingDocument.
  ///
  /// In en, this message translates to:
  /// **'Error loading document: {error}'**
  String errorLoadingDocument(String error);

  /// No description provided for @setListNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Set List Not Found'**
  String get setListNotFoundTitle;

  /// No description provided for @setListNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This set list could not be found.'**
  String get setListNotFoundMessage;

  /// No description provided for @backToSetLists.
  ///
  /// In en, this message translates to:
  /// **'Back to Set Lists'**
  String get backToSetLists;

  /// No description provided for @setListHasNoDocuments.
  ///
  /// In en, this message translates to:
  /// **'This set list has no documents.'**
  String get setListHasNoDocuments;

  /// No description provided for @editSetList.
  ///
  /// In en, this message translates to:
  /// **'Edit Set List'**
  String get editSetList;

  /// No description provided for @errorLoadingSetList.
  ///
  /// In en, this message translates to:
  /// **'Error loading set list: {error}'**
  String errorLoadingSetList(String error);

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get resetToDefaults;

  /// No description provided for @displaySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Settings'**
  String get displaySettingsTitle;

  /// No description provided for @exportPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdfTitle;

  /// No description provided for @selectLayersToInclude.
  ///
  /// In en, this message translates to:
  /// **'Select layers to include:'**
  String get selectLayersToInclude;

  /// No description provided for @exportingPageProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting page {current} of {total}...'**
  String exportingPageProgress(int current, int total);

  /// No description provided for @pleaseSelectAtLeastOneLayer.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one layer'**
  String get pleaseSelectAtLeastOneLayer;

  /// No description provided for @pdfDownloaded.
  ///
  /// In en, this message translates to:
  /// **'PDF downloaded'**
  String get pdfDownloaded;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get hidden;

  /// No description provided for @layersSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} layer(s) selected'**
  String layersSelected(int count);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @pen.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get pen;

  /// No description provided for @highlighter.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get highlighter;

  /// No description provided for @eraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get eraser;

  /// No description provided for @newLayer.
  ///
  /// In en, this message translates to:
  /// **'New layer'**
  String get newLayer;

  /// No description provided for @layers.
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layers;

  /// No description provided for @noLayers.
  ///
  /// In en, this message translates to:
  /// **'No layers'**
  String get noLayers;

  /// No description provided for @hideLayer.
  ///
  /// In en, this message translates to:
  /// **'Hide layer'**
  String get hideLayer;

  /// No description provided for @showLayer.
  ///
  /// In en, this message translates to:
  /// **'Show layer'**
  String get showLayer;

  /// No description provided for @cannotHideActiveLayer.
  ///
  /// In en, this message translates to:
  /// **'Cannot hide active layer'**
  String get cannotHideActiveLayer;

  /// No description provided for @deleteLayer.
  ///
  /// In en, this message translates to:
  /// **'Delete Layer'**
  String get deleteLayer;

  /// No description provided for @deleteLayerConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will delete all annotations on this layer.'**
  String deleteLayerConfirmation(String name);

  /// No description provided for @renameLayer.
  ///
  /// In en, this message translates to:
  /// **'Rename Layer'**
  String get renameLayer;

  /// No description provided for @layerName.
  ///
  /// In en, this message translates to:
  /// **'Layer name'**
  String get layerName;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @createNewSetList.
  ///
  /// In en, this message translates to:
  /// **'Create new set list'**
  String get createNewSetList;

  /// No description provided for @noSetListsYetCreateAbove.
  ///
  /// In en, this message translates to:
  /// **'No set lists yet. Create one above.'**
  String get noSetListsYetCreateAbove;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @previousDocument.
  ///
  /// In en, this message translates to:
  /// **'Previous document'**
  String get previousDocument;

  /// No description provided for @nextDocument.
  ///
  /// In en, this message translates to:
  /// **'Next document'**
  String get nextDocument;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @pagesRange.
  ///
  /// In en, this message translates to:
  /// **'Pages {start}-{end} of {total}'**
  String pagesRange(int start, int end, int total);

  /// No description provided for @pageSingle.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageSingle(int current, int total);

  /// No description provided for @documentNOfTotalBottom.
  ///
  /// In en, this message translates to:
  /// **'Document {index} of {total}'**
  String documentNOfTotalBottom(int index, int total);

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(String error);

  /// No description provided for @failedToRenderPage.
  ///
  /// In en, this message translates to:
  /// **'Failed to render page'**
  String get failedToRenderPage;

  /// No description provided for @failedToLoadDocumentGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to load document'**
  String get failedToLoadDocumentGeneric;

  /// No description provided for @errorLoadingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Error loading library: {error}'**
  String errorLoadingLibrary(String error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// No description provided for @sortByDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get sortByDateAdded;

  /// No description provided for @sortByFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get sortByFileSize;

  /// No description provided for @sortByPageCount.
  ///
  /// In en, this message translates to:
  /// **'Page count'**
  String get sortByPageCount;

  /// No description provided for @orDragAndDropHint.
  ///
  /// In en, this message translates to:
  /// **'or drag and drop PDF files here'**
  String get orDragAndDropHint;

  /// No description provided for @manageLabels.
  ///
  /// In en, this message translates to:
  /// **'Manage Labels'**
  String get manageLabels;

  /// No description provided for @manageLabelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rename, recolor, or delete labels'**
  String get manageLabelsSubtitle;

  /// No description provided for @noLabelsYet.
  ///
  /// In en, this message translates to:
  /// **'No labels yet'**
  String get noLabelsYet;

  /// No description provided for @changeLabelColor.
  ///
  /// In en, this message translates to:
  /// **'Change color'**
  String get changeLabelColor;

  /// No description provided for @pickAColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a color'**
  String get pickAColor;

  /// No description provided for @renameLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Label'**
  String get renameLabelTitle;

  /// No description provided for @deleteLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Label'**
  String get deleteLabelTitle;

  /// No description provided for @deleteLabelConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This removes it from all documents.'**
  String deleteLabelConfirmation(String name);

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @labels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get labels;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @renameDocument.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameDocument;

  /// No description provided for @renameDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Document'**
  String get renameDocumentTitle;

  /// No description provided for @documentRenamed.
  ///
  /// In en, this message translates to:
  /// **'Document renamed'**
  String get documentRenamed;

  /// No description provided for @renameFailedAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A file with that name already exists'**
  String get renameFailedAlreadyExists;

  /// No description provided for @renameFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to rename document'**
  String get renameFailedGeneric;

  /// No description provided for @addLabels.
  ///
  /// In en, this message translates to:
  /// **'Add Labels'**
  String get addLabels;

  /// No description provided for @newLabelName.
  ///
  /// In en, this message translates to:
  /// **'New label name'**
  String get newLabelName;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @createNewLabel.
  ///
  /// In en, this message translates to:
  /// **'Create new label'**
  String get createNewLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
