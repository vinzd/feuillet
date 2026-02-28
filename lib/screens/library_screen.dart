import 'package:desktop_drop/desktop_drop.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/database.dart';
import '../router/app_router.dart';
import '../services/annotation_service.dart';
import '../services/database_service.dart';
import '../services/file_access_service.dart';
import '../services/document_export_service.dart';
import '../services/document_service.dart';
import '../services/setlist_service.dart';
import '../services/version_service.dart';
import '../utils/fuzzy_search.dart';
import '../widgets/document_card.dart';
import '../widgets/setlist_picker_dialog.dart';
import '../widgets/export_pdf_dialog_web.dart'
    if (dart.library.io) '../widgets/export_pdf_dialog_native.dart'
    as platform;

/// Provider for the list of documents
final documentsProvider = StreamProvider<List<Document>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchAllDocuments();
});

/// Library screen showing all PDF documents
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

enum LibrarySortField { dateAdded, name, fileSize, pageCount }

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isGridView = true;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _importProgress;
  LibrarySortField _sortField = LibrarySortField.dateAdded;
  bool _sortAscending = false; // false = newest first for date, Z-A for name

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<int> _selectedDocumentIds = {};

  // Drag selection state
  bool _isDragSelecting = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  final Map<int, GlobalKey> _cardKeys = {};
  final Set<int> _dragSelectedIds = {};

  // File drop state
  bool _isDraggingFiles = false;

  @override
  void initState() {
    super.initState();
    _syncLibrary();
  }

  Future<void> _syncLibrary() async {
    setState(() => _isLoading = true);
    await DocumentService.instance.scanAndSyncLibrary();
    setState(() => _isLoading = false);
  }

  void _onImportProgress(int current, int total, String fileName) {
    if (mounted) {
      setState(() => _importProgress = 'Importing $current of $total...');
    }
  }

  void _onImportComplete(DocumentImportBatchResult? result) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _importProgress = null;
    });

    if (result != null && result.totalCount > 0) {
      _showImportResult(result);
    }
  }

  Future<void> _importDocuments() async {
    setState(() {
      _isLoading = true;
      _importProgress = null;
    });

    final result = await DocumentService.instance.importDocuments(
      onProgress: _onImportProgress,
    );

    _onImportComplete(result);
  }

  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    setState(() {
      _isLoading = true;
      _importProgress = null;
      _isDraggingFiles = false;
    });

    final result = await DocumentService.instance
        .importDocumentsFromDroppedFiles(
          details.files,
          onProgress: _onImportProgress,
        );

    _onImportComplete(result);
  }

  void _showImportResult(DocumentImportBatchResult result) {
    final messenger = ScaffoldMessenger.of(context);

    if (result.allSucceeded) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_formatSuccessMessage(result.totalCount)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final isAllFailures = result.successCount == 0;
    final message = isAllFailures
        ? _formatFailureMessage(result.failureCount)
        : 'Imported ${result.successCount} of ${result.totalCount} PDFs';

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isAllFailures
            ? Theme.of(context).colorScheme.error
            : null,
        action: SnackBarAction(
          label: 'Details',
          textColor: isAllFailures
              ? Theme.of(context).colorScheme.onError
              : null,
          onPressed: () => _showImportFailuresDialog(result.failures),
        ),
      ),
    );
  }

  String _pluralize(int count, String singular, {String? plural}) {
    return count == 1 ? singular : (plural ?? '${singular}s');
  }

  String _formatSuccessMessage(int count) {
    return 'Imported $count ${_pluralize(count, 'PDF')}';
  }

  String _formatFailureMessage(int count) {
    return 'Failed to import $count ${_pluralize(count, 'PDF')}';
  }

  String _formatAddToSetListMessage(int addedCount, int skippedCount) {
    if (skippedCount > 0 && addedCount > 0) {
      return 'Added $addedCount, skipped $skippedCount (already in set list)';
    }
    if (skippedCount > 0) {
      return 'All selected documents already in set list';
    }
    return 'Added $addedCount ${_pluralize(addedCount, 'document')} to set list';
  }

  void _showImportFailuresDialog(List<DocumentImportResult> failures) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Failures'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: failures.length,
            itemBuilder: (context, index) {
              final failure = failures[index];
              return ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(failure.fileName),
                subtitle: Text(failure.error ?? 'Unknown error'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdf(Document document) async {
    // Update last opened timestamp
    final updatedDoc = document.copyWith(lastOpened: Value(DateTime.now()));
    await ref.read(databaseProvider).updateDocument(updatedDoc);

    if (mounted) {
      context.push(AppRoutes.documentPath(document.id));
    }
  }

  List<Document> _filterDocuments(List<Document> documents) {
    var result = fuzzySearchDocuments(documents, _searchQuery);
    // When searching, preserve fuzzy relevance ordering;
    // when not searching, apply user-selected sort.
    if (_searchQuery.isEmpty) {
      result = List.of(result);
      switch (_sortField) {
        case LibrarySortField.name:
          result.sort(
            (a, b) => _sortAscending
                ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
                : b.name.toLowerCase().compareTo(a.name.toLowerCase()),
          );
        case LibrarySortField.dateAdded:
          result.sort(
            (a, b) => _sortAscending
                ? a.dateAdded.compareTo(b.dateAdded)
                : b.dateAdded.compareTo(a.dateAdded),
          );
        case LibrarySortField.fileSize:
          result.sort(
            (a, b) => _sortAscending
                ? a.fileSize.compareTo(b.fileSize)
                : b.fileSize.compareTo(a.fileSize),
          );
        case LibrarySortField.pageCount:
          result.sort(
            (a, b) => _sortAscending
                ? a.pageCount.compareTo(b.pageCount)
                : b.pageCount.compareTo(a.pageCount),
          );
      }
    }
    return result;
  }

  // Selection mode methods
  void _enterSelectionMode(Document document) {
    setState(() {
      _isSelectionMode = true;
      _selectedDocumentIds.add(document.id);
    });
  }

  void _handleCheckboxTap(Document document) {
    if (_isSelectionMode) {
      _toggleSelection(document);
    } else {
      _enterSelectionMode(document);
    }
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedDocumentIds.clear();
    });
  }

  void _toggleSelection(Document document) {
    setState(() {
      if (_selectedDocumentIds.contains(document.id)) {
        _selectedDocumentIds.remove(document.id);
        if (_selectedDocumentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedDocumentIds.add(document.id);
      }
    });
  }

  void _selectAll(List<Document> documents) {
    setState(() {
      _selectedDocumentIds.addAll(documents.map((d) => d.id));
    });
  }

  void _deselectAll() {
    _exitSelectionMode();
  }

  bool? _getSelectAllCheckboxState(List<Document> filteredDocs) {
    if (_selectedDocumentIds.isEmpty) return false;
    if (_selectedDocumentIds.length == filteredDocs.length &&
        filteredDocs.isNotEmpty) {
      return true;
    }
    return null; // Indeterminate state
  }

  Widget _buildSelectionTitle(List<Document> filteredDocs) {
    final checkboxState = _getSelectAllCheckboxState(filteredDocs);
    final allSelected = checkboxState == true;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: checkboxState,
          tristate: true,
          onChanged: (_) {
            if (allSelected) {
              _deselectAll();
            } else {
              _selectAll(filteredDocs);
            }
          },
        ),
        Text('${_selectedDocumentIds.length} selected'),
      ],
    );
  }

  void _handleDocumentTap(Document document) {
    if (_isSelectionMode) {
      _toggleSelection(document);
    } else {
      _openPdf(document);
    }
  }

  // Drag selection methods
  final GlobalKey _gridKey = GlobalKey();

  GlobalKey _getKeyForDocument(int docId) {
    return _cardKeys.putIfAbsent(docId, () => GlobalKey());
  }

  /// Returns the bounding rect of a card relative to the grid, or null if unavailable.
  Rect? _getCardRect(int docId) {
    final key = _cardKeys[docId];
    if (key?.currentContext == null) return null;

    final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) return null;

    final gridRenderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridRenderBox == null) return null;

    final cardPosition = renderBox.localToGlobal(
      Offset.zero,
      ancestor: gridRenderBox,
    );
    return cardPosition & renderBox.size;
  }

  bool _isPositionOnCard(Offset position, List<Document> docs) {
    for (final doc in docs) {
      final cardRect = _getCardRect(doc.id);
      if (cardRect != null && cardRect.contains(position)) {
        return true;
      }
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event, List<Document> docs) {
    // Only start drag selection if not starting on a card
    if (!_isPositionOnCard(event.localPosition, docs)) {
      setState(() {
        _isDragSelecting = true;
        _dragStart = event.localPosition;
        _dragCurrent = event.localPosition;
        _dragSelectedIds.clear();
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event, List<Document> docs) {
    if (_isDragSelecting) {
      setState(() {
        _dragCurrent = event.localPosition;
        _updateDragSelection(docs);
      });
    }
  }

  void _onPointerUp(PointerUpEvent event, List<Document> docs) {
    if (!_isDragSelecting) return;

    final wasClick =
        _dragStart != null &&
        _dragCurrent != null &&
        (_dragStart! - _dragCurrent!).distance < 5;

    if (_dragSelectedIds.isNotEmpty) {
      _applyDragSelection();
    } else if (wasClick &&
        _isSelectionMode &&
        !_isPositionOnCard(event.localPosition, docs)) {
      _exitSelectionMode();
    }

    _resetDragState();
  }

  void _applyDragSelection() {
    setState(() {
      _isSelectionMode = true;
      for (final docId in _dragSelectedIds) {
        if (_selectedDocumentIds.contains(docId)) {
          _selectedDocumentIds.remove(docId);
        } else {
          _selectedDocumentIds.add(docId);
        }
      }
      if (_selectedDocumentIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _resetDragState() {
    setState(() {
      _isDragSelecting = false;
      _dragStart = null;
      _dragCurrent = null;
      _dragSelectedIds.clear();
    });
  }

  void _updateDragSelection(List<Document> docs) {
    if (_dragStart == null || _dragCurrent == null) return;

    final selectionRect = Rect.fromPoints(_dragStart!, _dragCurrent!);
    _dragSelectedIds.clear();

    for (final doc in docs) {
      final cardRect = _getCardRect(doc.id);
      if (cardRect != null && selectionRect.overlaps(cardRect)) {
        _dragSelectedIds.add(doc.id);
      }
    }
  }

  Rect? get _selectionRect {
    if (_dragStart == null || _dragCurrent == null) return null;
    return Rect.fromPoints(_dragStart!, _dragCurrent!);
  }

  // Bulk action methods
  Future<void> _addSelectedToSetList() async {
    final setListId = await SetListPickerDialog.show(context);
    if (setListId == null || !mounted) return;

    final setListService = SetListService();

    // Get existing documents in the target set list to avoid duplicates
    final existingDocs = await setListService.getSetListDocuments(setListId);
    final existingDocIds = existingDocs.map((d) => d.id).toSet();

    int addedCount = 0;
    int skippedCount = 0;

    for (final docId in _selectedDocumentIds) {
      if (existingDocIds.contains(docId)) {
        skippedCount++;
      } else {
        await setListService.addDocumentToSetList(
          setListId: setListId,
          documentId: docId,
        );
        addedCount++;
      }
    }

    await setListService.touchSetList(setListId);

    if (mounted) {
      final message = _formatAddToSetListMessage(addedCount, skippedCount);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _exitSelectionMode();
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedDocumentIds.length;
    final deleteFiles = await _showDeleteConfirmationDialog(count);

    if (deleteFiles == null || !mounted) return;

    for (final docId in _selectedDocumentIds) {
      await DocumentService.instance.deleteDocument(
        docId,
        deleteFile: deleteFiles,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $count ${_pluralize(count, 'document')}'),
        ),
      );
      _exitSelectionMode();
    }
  }

  Future<void> _exportSelected() async {
    final documents = await ref.read(databaseProvider).getAllDocuments();
    final selectedDocs = documents
        .where((d) => _selectedDocumentIds.contains(d.id))
        .toList();

    if (selectedDocs.isEmpty) return;

    // Show export progress dialog
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BulkExportDialog(documents: selectedDocs),
    );

    if (mounted) {
      _exitSelectionMode();
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(int count) async {
    bool deleteFiles = false;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Documents'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete $count ${_pluralize(count, 'document')}?',
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: deleteFiles,
                onChanged: (value) {
                  setDialogState(() => deleteFiles = value ?? false);
                },
                title: const Text('Also delete PDF files from disk'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, deleteFiles),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionActionBar() {
    final hasSelection = _selectedDocumentIds.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasSelection ? _addSelectedToSetList : null,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add to Set List'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasSelection ? _exportSelected : null,
                icon: const Icon(Icons.ios_share),
                label: const Text('Export'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: hasSelection ? _deleteSelected : null,
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: hasSelection ? Colors.red : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLibraryEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            isLibraryEmpty ? 'No PDFs in library' : 'No PDFs match your search',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (isLibraryEmpty)
            ElevatedButton.icon(
              onPressed: _importDocuments,
              icon: const Icon(Icons.add),
              label: const Text('Import PDFs'),
            ),
          if (isLibraryEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'or drag and drop PDF files here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropZoneOverlay() {
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).colorScheme.primary.withAlpha(30),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.file_download,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Drop PDF files here',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentList(List<Document> documents) {
    if (_isGridView) {
      return Listener(
        key: _gridKey,
        onPointerDown: (event) => _onPointerDown(event, documents),
        onPointerMove: (event) => _onPointerMove(event, documents),
        onPointerUp: (event) => _onPointerUp(event, documents),
        onPointerCancel: (_) => _onPointerUp(const PointerUpEvent(), documents),
        child: Stack(
          children: [
            GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                final isInDragSelection = _dragSelectedIds.contains(doc.id);
                final isCurrentlySelected = _selectedDocumentIds.contains(
                  doc.id,
                );
                // Show as selected if either already selected or in current drag
                // but not both (XOR for toggle preview)
                final showSelected = isCurrentlySelected ^ isInDragSelection;
                return DocumentCard(
                  key: _getKeyForDocument(doc.id),
                  document: doc,
                  onTap: () => _handleDocumentTap(doc),
                  onLongPress: () => _enterSelectionMode(doc),
                  onCheckboxTap: () => _handleCheckboxTap(doc),
                  isSelectionMode: _isSelectionMode || _isDragSelecting,
                  isSelected: showSelected,
                );
              },
            ),
            if (_isDragSelecting && _selectionRect != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SelectionRectPainter(
                      rect: _selectionRect!,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          return PdfListTile(
            document: doc,
            onTap: () => _handleDocumentTap(doc),
            onLongPress: () => _enterSelectionMode(doc),
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedDocumentIds.contains(doc.id),
          );
        },
      );
    }
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading library: $error'),
          ElevatedButton(onPressed: _syncLibrary, child: const Text('Retry')),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AsyncValue<List<Document>> documentsAsync,
    AsyncValue<VersionInfo> versionInfo,
  ) {
    if (_isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
          tooltip: 'Cancel selection',
        ),
        title:
            documentsAsync.whenOrNull(
              data: (documents) {
                final filteredDocs = _filterDocuments(documents);
                return _buildSelectionTitle(filteredDocs);
              },
            ) ??
            Text('${_selectedDocumentIds.length} selected'),
      );
    }

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Feuillet'),
          const SizedBox(width: 8),
          versionInfo.when(
            data: (info) => Text(
              info.displayString,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () {
            setState(() => _isGridView = !_isGridView);
          },
          tooltip: _isGridView ? 'List view' : 'Grid view',
        ),
        PopupMenuButton<LibrarySortField>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort order',
          onSelected: (field) {
            setState(() {
              if (_sortField == field) {
                _sortAscending = !_sortAscending;
              } else {
                _sortField = field;
                // Default: A-Z for name, descending for everything else
                _sortAscending = field == LibrarySortField.name;
              }
            });
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: LibrarySortField.name,
              child: Row(
                children: [
                  const Expanded(child: Text('Name')),
                  if (_sortField == LibrarySortField.name)
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: LibrarySortField.dateAdded,
              child: Row(
                children: [
                  const Expanded(child: Text('Date added')),
                  if (_sortField == LibrarySortField.dateAdded)
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: LibrarySortField.fileSize,
              child: Row(
                children: [
                  const Expanded(child: Text('File size')),
                  if (_sortField == LibrarySortField.fileSize)
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                    ),
                ],
              ),
            ),
            PopupMenuItem(
              value: LibrarySortField.pageCount,
              child: Row(
                children: [
                  const Expanded(child: Text('Page count')),
                  if (_sortField == LibrarySortField.pageCount)
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 18,
                    ),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _syncLibrary,
          tooltip: 'Sync library',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            context.push(AppRoutes.settings);
          },
          tooltip: 'Settings',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider);

    final versionInfo = ref.watch(versionInfoProvider);

    return Scaffold(
      appBar: _buildAppBar(context, documentsAsync, versionInfo),
      body: DropTarget(
        onDragDone: _handleDroppedFiles,
        onDragEntered: (_) => setState(() => _isDraggingFiles = true),
        onDragExited: (_) => setState(() => _isDraggingFiles = false),
        child: Stack(
          children: [
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search PDFs...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),

                // Document grid/list
                Expanded(
                  child: documentsAsync.when(
                    data: (documents) {
                      final filteredDocs = _filterDocuments(documents);
                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState(documents.isEmpty);
                      }
                      return _buildDocumentList(filteredDocs);
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => _buildErrorState(error),
                  ),
                ),

                // Selection action bar
                if (_isSelectionMode) _buildSelectionActionBar(),
              ],
            ),
            // Drop zone overlay
            if (_isDraggingFiles) _buildDropZoneOverlay(),
          ],
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLoading ? null : _importDocuments,
              tooltip: 'Import PDFs',
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_importProgress ?? 'Import'),
            ),
    );
  }
}

/// Dialog for bulk exporting PDFs with annotations
class _BulkExportDialog extends StatefulWidget {
  final List<Document> documents;

  const _BulkExportDialog({required this.documents});

  @override
  State<_BulkExportDialog> createState() => _BulkExportDialogState();
}

class _BulkExportDialogState extends State<_BulkExportDialog> {
  final _exportService = DocumentExportService.instance;
  final _annotationService = AnnotationService();

  bool _isExporting = false;
  int _currentDocIndex = 0;
  int _currentPage = 0;
  int _totalPages = 0;
  String _currentDocName = '';
  int _successCount = 0;
  int _failCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _error = null;
    });

    for (int i = 0; i < widget.documents.length; i++) {
      if (!mounted) return;

      final doc = widget.documents[i];
      setState(() {
        _currentDocIndex = i;
        _currentDocName = doc.name;
        _currentPage = 0;
        _totalPages = doc.pageCount;
      });

      try {
        await _exportDocument(doc);
        _successCount++;
      } catch (e) {
        debugPrint('Failed to export ${doc.name}: $e');
        _failCount++;
      }
    }

    if (mounted) {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportDocument(Document doc) async {
    // Load the PDF document
    final pdfDoc = await FileAccessService.instance.openPdfDocument(
      doc.filePath,
      pdfBytes: doc.pdfBytes != null ? Uint8List.fromList(doc.pdfBytes!) : null,
    );

    try {
      // Get visible layers for this document
      final layers = await _annotationService.getLayers(doc.id);
      final visibleLayerIds = layers
          .where((l) => l.isVisible)
          .map((l) => l.id)
          .toList();

      // Export with visible layers
      final pdfBytes = await _exportService.exportPdfWithAnnotations(
        document: doc,
        pdfDoc: pdfDoc,
        selectedLayerIds: visibleLayerIds,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentPage = current;
              _totalPages = total;
            });
          }
        },
      );

      // Generate filename
      final baseName = doc.name.replaceAll('.pdf', '');
      final fileName = '${baseName}_annotated.pdf';

      if (kIsWeb) {
        platform.downloadPdf(pdfBytes, fileName);
      } else {
        await _exportService.sharePdf(pdfBytes, fileName);
      }
    } finally {
      await pdfDoc.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isExporting ? 'Exporting...' : 'Export Complete'),
      content: SizedBox(width: 300, child: _buildContent()),
      actions: [
        if (!_isExporting)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_isExporting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Document ${_currentDocIndex + 1} of ${widget.documents.length}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(_currentDocName, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            'Page $_currentPage of $_totalPages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    // Export complete
    final hasFailures = _failCount > 0;
    final documentLabel = _successCount == 1 ? 'document' : 'documents';
    final resultMessage = hasFailures
        ? 'Exported $_successCount, failed $_failCount'
        : 'Exported $_successCount $documentLabel';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasFailures ? Icons.warning : Icons.check_circle,
          size: 48,
          color: hasFailures ? Colors.orange : Colors.green,
        ),
        const SizedBox(height: 16),
        Text(resultMessage),
      ],
    );
  }
}

/// List tile widget for list view
class PdfListTile extends StatefulWidget {
  final Document document;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const PdfListTile({
    super.key,
    required this.document,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  State<PdfListTile> createState() => _PdfListTileState();
}

class _PdfListTileState extends State<PdfListTile> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(PdfListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() => _isLoading = true);

    try {
      final bytes = await DocumentService.instance.generateThumbnail(
        widget.document,
      );
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLeadingWidget() {
    if (_isLoading) {
      return const SizedBox(
        width: 40,
        height: 56,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_thumbnailBytes == null) {
      return const Icon(Icons.picture_as_pdf, size: 40);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.memory(
        _thumbnailBytes!,
        width: 40,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.picture_as_pdf, size: 40);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      shape: widget.isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.primary, width: 2),
            )
          : null,
      child: ListTile(
        leading: widget.isSelectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onTap(),
                  ),
                  _buildLeadingWidget(),
                ],
              )
            : _buildLeadingWidget(),
        title: Text(widget.document.name),
        subtitle: Text(
          '${widget.document.pageCount} pages • ${_formatFileSize(widget.document.fileSize)}',
        ),
        trailing: widget.isSelectionMode
            ? null
            : const Icon(Icons.chevron_right),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Custom painter for the selection rectangle
class _SelectionRectPainter extends CustomPainter {
  final Rect rect;
  final Color color;

  _SelectionRectPainter({required this.rect, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw filled rectangle with low opacity
    final fillPaint = Paint()
      ..color = color.withAlpha(30)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = color.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_SelectionRectPainter oldDelegate) {
    return rect != oldDelegate.rect || color != oldDelegate.color;
  }
}
