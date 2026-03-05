// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get library => 'Bibliothèque';

  @override
  String get setLists => 'Listes';

  @override
  String get cancelSelection => 'Annuler la sélection';

  @override
  String get listView => 'Vue en liste';

  @override
  String get gridView => 'Vue en grille';

  @override
  String get sortOrder => 'Ordre de tri';

  @override
  String get syncLibrary => 'Synchroniser la bibliothèque';

  @override
  String get settings => 'Réglages';

  @override
  String get importPdfs => 'Importer des PDF';

  @override
  String get searchPdfsHint => 'Rechercher des PDF...';

  @override
  String nSelected(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get addToSetList => 'Ajouter à une liste';

  @override
  String get export => 'Exporter';

  @override
  String get delete => 'Supprimer';

  @override
  String get noPdfsInLibrary => 'Aucun PDF dans la bibliothèque';

  @override
  String get noPdfsMatchSearch => 'Aucun PDF ne correspond à la recherche';

  @override
  String importingProgress(int current, int total) {
    return 'Import de $current sur $total...';
  }

  @override
  String importedCountOfTotal(int successCount, int totalCount) {
    return '$successCount sur $totalCount PDF importés';
  }

  @override
  String importedPdfs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PDF importés',
      one: '1 PDF importé',
    );
    return '$_temp0';
  }

  @override
  String failedToImportPdfs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Échec de l\'import de $count PDF',
      one: 'Échec de l\'import d\'1 PDF',
    );
    return '$_temp0';
  }

  @override
  String addedAndSkipped(int addedCount, int skippedCount) {
    return '$addedCount ajouté(s), $skippedCount ignoré(s) (déjà dans la liste)';
  }

  @override
  String get allSelectedAlreadyInSetList =>
      'Tous les documents sélectionnés sont déjà dans la liste';

  @override
  String addedDocumentsToSetList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents ajoutés à la liste',
      one: '1 document ajouté à la liste',
    );
    return '$_temp0';
  }

  @override
  String get details => 'Détails';

  @override
  String get importFailures => 'Échecs d\'import';

  @override
  String get unknownError => 'Erreur inconnue';

  @override
  String get ok => 'OK';

  @override
  String get deleteDocuments => 'Supprimer les documents';

  @override
  String deleteDocumentsConfirmation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Voulez-vous vraiment supprimer $count documents ?',
      one: 'Voulez-vous vraiment supprimer 1 document ?',
    );
    return '$_temp0';
  }

  @override
  String get alsoDeleteFromDisk => 'Supprimer aussi les fichiers PDF du disque';

  @override
  String get cancel => 'Annuler';

  @override
  String deletedDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents supprimés',
      one: '1 document supprimé',
    );
    return '$_temp0';
  }

  @override
  String get exporting => 'Export en cours...';

  @override
  String get exportComplete => 'Export terminé';

  @override
  String documentNOfTotal(int index, int total) {
    return 'Document $index sur $total';
  }

  @override
  String pageNOfTotal(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String exportedSuccessFailCount(int successCount, int failCount) {
    return '$successCount exporté(s), $failCount échoué(s)';
  }

  @override
  String exportedDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents exportés',
      one: '1 document exporté',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Terminé';

  @override
  String get viewMode => 'Mode d\'affichage';

  @override
  String get annotations => 'Annotations';

  @override
  String get displaySettings => 'Réglages d\'affichage';

  @override
  String get exportImage => 'Exporter l\'image';

  @override
  String get exportPdf => 'Exporter le PDF';

  @override
  String get failedToLoadDocument =>
      'Échec du chargement du document. Veuillez réessayer.';

  @override
  String get exportingImage => 'Export de l\'image...';

  @override
  String get webExportNotSupported =>
      'L\'export d\'images n\'est pas encore disponible sur le web';

  @override
  String exportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get selectAnnotationLayers =>
      'Sélectionner les calques d\'annotations à inclure :';

  @override
  String get noAnnotationLayersFound => 'Aucun calque d\'annotations trouvé.';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get librarySection => 'Bibliothèque';

  @override
  String get pdfDirectory => 'Dossier PDF';

  @override
  String get resetToDefault => 'Réinitialiser par défaut';

  @override
  String get changeDirectory => 'Changer de dossier';

  @override
  String get customDirectory => 'Dossier personnalisé';

  @override
  String get resetToDefaultTitle => 'Réinitialiser par défaut';

  @override
  String get resetToDefaultMessage =>
      'Le dossier PDF sera réinitialisé à l\'emplacement par défaut. Vos PDF existants resteront à leur emplacement actuel.';

  @override
  String get reset => 'Réinitialiser';

  @override
  String pdfDirectoryUpdated(String path) {
    return 'Dossier PDF mis à jour : $path';
  }

  @override
  String errorUpdatingDirectory(String error) {
    return 'Erreur de mise à jour du dossier : $error';
  }

  @override
  String get resetToDefaultPdfDirectory =>
      'Dossier PDF réinitialisé par défaut';

  @override
  String errorResettingDirectory(String error) {
    return 'Erreur de réinitialisation du dossier : $error';
  }

  @override
  String get customDirectoryNotAvailableOnWeb =>
      'Le dossier PDF personnalisé n\'est pas disponible sur le web.';

  @override
  String get aboutSection => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get loading => 'Chargement...';

  @override
  String get unknown => 'Inconnu';

  @override
  String get newSetList => 'Nouvelle liste';

  @override
  String get name => 'Nom';

  @override
  String get descriptionOptional => 'Description (facultatif)';

  @override
  String get create => 'Créer';

  @override
  String get deleteSetList => 'Supprimer la liste';

  @override
  String deleteSetListConfirmation(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ?';
  }

  @override
  String get renameSetList => 'Renommer la liste';

  @override
  String get rename => 'Renommer';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String get setListDuplicated => 'Liste dupliquée';

  @override
  String errorLoadingSetLists(String error) {
    return 'Erreur de chargement des listes : $error';
  }

  @override
  String get addDocumentsToStartPerformance =>
      'Ajoutez des documents pour démarrer le mode performance';

  @override
  String get startPerformance => 'Démarrer la performance';

  @override
  String get noSetListsYet => 'Aucune liste pour le moment';

  @override
  String get createSetList => 'Créer une liste';

  @override
  String get noDocuments => 'Aucun document';

  @override
  String get setList => 'Liste';

  @override
  String get setListNotFound => 'Liste introuvable';

  @override
  String get noDocumentsInSetList => 'Aucun document dans cette liste';

  @override
  String get addDocuments => 'Ajouter des documents';

  @override
  String get allDocumentsAlreadyInSetList =>
      'Tous les documents sont déjà dans cette liste';

  @override
  String get searchDocumentsHint => 'Rechercher des documents...';

  @override
  String nPages(int count) {
    return '$count pages';
  }

  @override
  String addCount(int count) {
    return 'Ajouter ($count)';
  }

  @override
  String get view => 'Voir';

  @override
  String get remove => 'Retirer';

  @override
  String get enterLabelHint => 'Saisir un libellé...';

  @override
  String get addLabel => 'Ajouter un libellé';

  @override
  String get documentsInSetList => 'Documents de la liste';

  @override
  String pagesCount(int count) {
    return '$count pages';
  }

  @override
  String get documentList => 'Liste des documents';

  @override
  String get documentNotFound => 'Document introuvable';

  @override
  String get documentNotFoundMessage => 'Ce document est introuvable.';

  @override
  String get backToLibrary => 'Retour à la bibliothèque';

  @override
  String get error => 'Erreur';

  @override
  String errorLoadingDocument(String error) {
    return 'Erreur de chargement du document : $error';
  }

  @override
  String get setListNotFoundTitle => 'Liste introuvable';

  @override
  String get setListNotFoundMessage => 'Cette liste est introuvable.';

  @override
  String get backToSetLists => 'Retour aux listes';

  @override
  String get setListHasNoDocuments => 'Cette liste ne contient aucun document.';

  @override
  String get editSetList => 'Modifier la liste';

  @override
  String errorLoadingSetList(String error) {
    return 'Erreur de chargement de la liste : $error';
  }

  @override
  String get brightness => 'Luminosité';

  @override
  String get contrast => 'Contraste';

  @override
  String get resetToDefaults => 'Réinitialiser';

  @override
  String get displaySettingsTitle => 'Réglages d\'affichage';

  @override
  String get exportPdfTitle => 'Exporter le PDF';

  @override
  String get selectLayersToInclude => 'Sélectionner les calques à inclure :';

  @override
  String exportingPageProgress(int current, int total) {
    return 'Export de la page $current sur $total...';
  }

  @override
  String get pleaseSelectAtLeastOneLayer =>
      'Veuillez sélectionner au moins un calque';

  @override
  String get pdfDownloaded => 'PDF téléchargé';

  @override
  String get hidden => 'Masqué';

  @override
  String layersSelected(int count) {
    return '$count calque(s) sélectionné(s)';
  }

  @override
  String get close => 'Fermer';

  @override
  String get pen => 'Stylo';

  @override
  String get highlighter => 'Surligneur';

  @override
  String get eraser => 'Gomme';

  @override
  String get newLayer => 'Nouveau calque';

  @override
  String get layers => 'Calques';

  @override
  String get noLayers => 'Aucun calque';

  @override
  String get hideLayer => 'Masquer le calque';

  @override
  String get showLayer => 'Afficher le calque';

  @override
  String get cannotHideActiveLayer => 'Impossible de masquer le calque actif';

  @override
  String get deleteLayer => 'Supprimer le calque';

  @override
  String deleteLayerConfirmation(String name) {
    return 'Voulez-vous vraiment supprimer « $name » ? Toutes les annotations de ce calque seront supprimées.';
  }

  @override
  String get renameLayer => 'Renommer le calque';

  @override
  String get layerName => 'Nom du calque';

  @override
  String get confirm => 'Confirmer';

  @override
  String get createNewSetList => 'Créer une nouvelle liste';

  @override
  String get noSetListsYetCreateAbove =>
      'Aucune liste. Créez-en une ci-dessus.';

  @override
  String get add => 'Ajouter';

  @override
  String get previousDocument => 'Document précédent';

  @override
  String get nextDocument => 'Document suivant';

  @override
  String get previousPage => 'Page précédente';

  @override
  String get nextPage => 'Page suivante';

  @override
  String pagesRange(int start, int end, int total) {
    return 'Pages $start-$end sur $total';
  }

  @override
  String pageSingle(int current, int total) {
    return 'Page $current sur $total';
  }

  @override
  String documentNOfTotalBottom(int index, int total) {
    return 'Document $index sur $total';
  }

  @override
  String errorPrefix(String error) {
    return 'Erreur : $error';
  }

  @override
  String get failedToRenderPage => 'Échec du rendu de la page';

  @override
  String get failedToLoadDocumentGeneric => 'Échec du chargement du document';

  @override
  String errorLoadingLibrary(String error) {
    return 'Erreur de chargement de la bibliothèque : $error';
  }

  @override
  String get retry => 'Réessayer';

  @override
  String get sortByName => 'Nom';

  @override
  String get sortByDateAdded => 'Date d\'ajout';

  @override
  String get sortByFileSize => 'Taille du fichier';

  @override
  String get sortByPageCount => 'Nombre de pages';

  @override
  String get orDragAndDropHint => 'ou glissez-déposez des fichiers PDF ici';

  @override
  String get manageLabels => 'Gérer les étiquettes';

  @override
  String get manageLabelsSubtitle =>
      'Renommer, recolorer ou supprimer des étiquettes';

  @override
  String get noLabelsYet => 'Aucune étiquette pour le moment';

  @override
  String get changeLabelColor => 'Changer la couleur';

  @override
  String get pickAColor => 'Choisir une couleur';

  @override
  String get renameLabelTitle => 'Renommer l\'étiquette';

  @override
  String get deleteLabelTitle => 'Supprimer l\'étiquette';

  @override
  String deleteLabelConfirmation(String name) {
    return 'Supprimer « $name » ? L\'étiquette sera retirée de tous les documents.';
  }

  @override
  String get label => 'Étiquette';

  @override
  String get labels => 'Étiquettes';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get addLabels => 'Ajouter des étiquettes';

  @override
  String get newLabelName => 'Nom de la nouvelle étiquette';

  @override
  String get apply => 'Appliquer';

  @override
  String get createNewLabel => 'Créer une nouvelle étiquette';
}
