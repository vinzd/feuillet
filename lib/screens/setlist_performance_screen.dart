import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../models/database.dart';
import '../models/view_mode.dart';
import '../services/file_access_service.dart';
import '../services/pdf_page_cache_service.dart';
import '../utils/auto_hide_controller.dart';
import '../utils/display_settings.dart';
import '../utils/zoom_pan_gesture_handler.dart';
import '../widgets/display_settings_panel.dart';
import '../widgets/performance_bottom_controls.dart';
import '../widgets/performance_document_view.dart';

/// Performance mode for set lists with quick navigation.
///
/// Features:
/// - Multiple view modes (single, booklet, continuous double)
/// - Keyboard navigation (arrow keys for pages, shift+arrows for documents)
/// - Pre-rendering for faster page loads
/// - Read-only annotation display
class SetListPerformanceScreen extends StatefulWidget {
  final int setListId;
  final List<Document> documents;

  const SetListPerformanceScreen({
    super.key,
    required this.setListId,
    required this.documents,
  });

  @override
  State<SetListPerformanceScreen> createState() =>
      _SetListPerformanceScreenState();
}

class _SetListPerformanceScreenState extends State<SetListPerformanceScreen>
    with ZoomPanGestureMixin {
  late PageController _documentPageController;
  int _currentDocIndex = 0;

  final Map<int, PdfDocument> _pdfDocuments = {};
  final Map<int, bool> _documentLoading = {};
  final Map<int, int> _currentPages = {};
  final Map<int, GlobalKey<PerformanceDocumentViewState>> _documentViewKeys =
      {};

  PdfViewMode _viewMode = PdfViewMode.single;
  late final AutoHideController _autoHideController;
  final FocusNode _focusNode = FocusNode();

  @override
  late final ZoomPanState zoomPanState;

  int _currentPage = 1;
  int? _currentRightPage;

  @override
  void initState() {
    super.initState();
    zoomPanState = ZoomPanState(displaySettings: DisplaySettings.defaults);
    _autoHideController = AutoHideController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _documentPageController = PageController();
    _initializeDocuments();
  }

  @override
  void onZoomPanTap() => _autoHideController.toggle();

  Future<void> _initializeDocuments() async {
    // Load the first document immediately
    await _ensureDocumentLoaded(0);

    // Pre-load adjacent documents
    _preloadAdjacentDocuments();
  }

  Future<PdfDocument?> _ensureDocumentLoaded(int index) async {
    if (index < 0 || index >= widget.documents.length) return null;

    // Return if already loaded
    if (_pdfDocuments.containsKey(index)) {
      return _pdfDocuments[index];
    }

    // Return if already loading
    if (_documentLoading[index] == true) {
      // Wait for it to finish
      while (_documentLoading[index] == true) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _pdfDocuments[index];
    }

    // Start loading
    _documentLoading[index] = true;

    try {
      final doc = widget.documents[index];
      final pdfDocument = await FileAccessService.instance.openPdfDocument(
        doc.filePath,
        pdfBytes: doc.pdfBytes != null
            ? Uint8List.fromList(doc.pdfBytes!)
            : null,
      );

      _pdfDocuments[index] = pdfDocument;

      // Initialize page tracking for this document
      _currentPages[index] = 1;

      // Create a key for the view
      _documentViewKeys[index] = GlobalKey<PerformanceDocumentViewState>();

      if (mounted) setState(() {});

      return pdfDocument;
    } catch (e) {
      debugPrint('Error loading document $index: $e');
      return null;
    } finally {
      _documentLoading[index] = false;
    }
  }

  void _preloadAdjacentDocuments() {
    final cacheService = PdfPageCacheService.instance;

    // Pre-load next document and pre-render its first pages in background
    if (_currentDocIndex < widget.documents.length - 1) {
      final nextDocIndex = _currentDocIndex + 1;
      _ensureDocumentLoaded(nextDocIndex).then((pdfDoc) {
        if (pdfDoc != null) {
          final totalPages = widget.documents[nextDocIndex].pageCount;

          // Pre-render page 1 first (this is what will be shown immediately)
          cacheService.renderAndCachePage(document: pdfDoc, pageNumber: 1);

          // Pre-render page 2 for two-page modes
          if (totalPages > 1) {
            cacheService.renderAndCachePage(document: pdfDoc, pageNumber: 2);
          }

          // Then pre-render additional pages in background
          cacheService.preRenderPages(
            document: pdfDoc,
            currentPage: 1,
            totalPages: totalPages,
          );
        }
      });
    }

    // Pre-load previous document and pre-render its last pages
    if (_currentDocIndex > 0) {
      final prevDocIndex = _currentDocIndex - 1;
      _ensureDocumentLoaded(prevDocIndex).then((pdfDoc) {
        if (pdfDoc != null) {
          final totalPages = widget.documents[prevDocIndex].pageCount;

          // Pre-render last page first (this is what will be shown immediately)
          cacheService.renderAndCachePage(
            document: pdfDoc,
            pageNumber: totalPages,
          );

          // Pre-render second-to-last page for two-page modes
          if (totalPages > 1) {
            cacheService.renderAndCachePage(
              document: pdfDoc,
              pageNumber: totalPages - 1,
            );
          }

          // Then pre-render additional pages in background
          cacheService.preRenderPages(
            document: pdfDoc,
            currentPage: totalPages,
            totalPages: totalPages,
          );
        }
      });
    }

    // Clean up distant documents (more than 2 positions away)
    _cleanupDistantDocuments();
  }

  void _cleanupDistantDocuments() {
    final keysToRemove = <int>[];
    for (final index in _pdfDocuments.keys) {
      if ((index - _currentDocIndex).abs() > 2) {
        keysToRemove.add(index);
      }
    }
    for (final index in keysToRemove) {
      // Clear the cache for this document
      final pdfDoc = _pdfDocuments[index];
      if (pdfDoc != null) {
        PdfPageCacheService.instance.clearDocument(pdfDoc.id);
      }
      _pdfDocuments.remove(index);
      _documentViewKeys.remove(index);
    }
  }

  @override
  void dispose() {
    _autoHideController.dispose();
    _documentPageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToNextDocument() {
    if (_currentDocIndex < widget.documents.length - 1) {
      _documentPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousDocument() {
    if (_currentDocIndex > 0) {
      _documentPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToDocument(int index) {
    _documentPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onDocumentChanged(int index) {
    setState(() {
      _currentDocIndex = index;
      // Restore the page position for this document
      _currentPage = _currentPages[index] ?? 1;
      _currentRightPage = null; // Will be updated by onPageChanged callback
    });
    _preloadAdjacentDocuments();
  }

  void _onPageChanged(int docIndex, ({int left, int? right}) spread) {
    if (docIndex == _currentDocIndex) {
      setState(() {
        _currentPage = spread.left;
        _currentRightPage = spread.right;
        _currentPages[docIndex] = spread.left;
      });
    } else {
      _currentPages[docIndex] = spread.left;
    }
  }

  void _goToNextPage() {
    final viewKey = _documentViewKeys[_currentDocIndex];
    viewKey?.currentState?.goToNext();
  }

  void _goToPreviousPage() {
    final viewKey = _documentViewKeys[_currentDocIndex];
    viewKey?.currentState?.goToPrevious();
  }

  void _onReachedDocumentStart() {
    // At first page, go to previous document's last page
    if (_currentDocIndex > 0) {
      _goToPreviousDocument();
      // After the document change animation, jump to the last page
      Future.delayed(const Duration(milliseconds: 350), () {
        final viewKey = _documentViewKeys[_currentDocIndex];
        viewKey?.currentState?.goToLast();
      });
    }
  }

  void _onReachedDocumentEnd() {
    // At last page, go to next document
    if (_currentDocIndex < widget.documents.length - 1) {
      _goToNextDocument();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // Shift+arrow for document navigation
    if (isShiftPressed) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _goToPreviousDocument();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _goToNextDocument();
        return KeyEventResult.handled;
      }
    }

    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        _goToPreviousDocument();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _goToNextDocument();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.pageUp:
        _goToPreviousPage();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        _goToNextPage();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _documentViewKeys[_currentDocIndex]?.currentState?.goToFirst();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _documentViewKeys[_currentDocIndex]?.currentState?.goToLast();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _onViewModeChanged(PdfViewMode mode) {
    setState(() => _viewMode = mode);
  }

  void _showDisplaySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => DisplaySettingsPanel(
        brightness: zoomPanState.displaySettings.brightness,
        contrast: zoomPanState.displaySettings.contrast,
        onBrightnessChanged: (value) => setState(
          () => zoomPanState.displaySettings = zoomPanState.displaySettings
              .copyWith(brightness: value),
        ),
        onContrastChanged: (value) => setState(
          () => zoomPanState.displaySettings = zoomPanState.displaySettings
              .copyWith(contrast: value),
        ),
        onReset: () {
          setState(() {
            zoomPanState.displaySettings = zoomPanState.displaySettings
                .copyWith(brightness: 0.0, contrast: 1.0);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: buildZoomPanGestureDetector(
          child: Stack(
            children: [
              ColorFiltered(
                colorFilter: zoomPanState.displaySettings.colorFilter,
                child: buildZoomPanTransform(
                  child: PageView.builder(
                    controller: _documentPageController,
                    itemCount: widget.documents.length,
                    onPageChanged: _onDocumentChanged,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable swipe, use buttons only
                    itemBuilder: (context, index) {
                      final pdfDocument = _pdfDocuments[index];
                      if (pdfDocument == null) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      return PerformanceDocumentView(
                        key: _documentViewKeys[index],
                        document: widget.documents[index],
                        pdfDocument: pdfDocument,
                        viewMode: _viewMode,
                        initialPage: _currentPages[index] ?? 1,
                        onReachedStart: _onReachedDocumentStart,
                        onReachedEnd: _onReachedDocumentEnd,
                        onPageChanged: (spread) =>
                            _onPageChanged(index, spread),
                      );
                    },
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _autoHideController.isVisible ? 0 : -100,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  title: Text(
                    widget.documents[_currentDocIndex].name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    // View mode selector
                    PopupMenuButton<PdfViewMode>(
                      icon: Icon(_viewMode.icon, color: Colors.white),
                      tooltip: 'View mode',
                      onSelected: _onViewModeChanged,
                      itemBuilder: (context) => PdfViewMode.values
                          .map(
                            (mode) => PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  Icon(
                                    mode.icon,
                                    color: mode == _viewMode
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(mode.displayName),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    // Display settings
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white),
                      onPressed: _showDisplaySettings,
                      tooltip: 'Display settings',
                    ),
                    // Document list
                    IconButton(
                      icon: const Icon(Icons.list),
                      onPressed: _showDocumentList,
                      tooltip: 'Document list',
                    ),
                  ],
                ),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _autoHideController.isVisible ? 0 : -200,
                left: 0,
                right: 0,
                child: PerformanceBottomControls(
                  currentDocIndex: _currentDocIndex,
                  totalDocs: widget.documents.length,
                  currentDocName: widget.documents[_currentDocIndex].name,
                  currentPage: _currentPage,
                  rightPage: _currentRightPage,
                  totalPages: widget.documents[_currentDocIndex].pageCount,
                  viewMode: _viewMode,
                  zoomLevel: zoomPanState.displaySettings.zoomLevel,
                  onPrevDoc: _currentDocIndex > 0
                      ? _goToPreviousDocument
                      : null,
                  onNextDoc: _currentDocIndex < widget.documents.length - 1
                      ? _goToNextDocument
                      : null,
                  onPrevPage: _goToPreviousPage,
                  onNextPage: _goToNextPage,
                  onZoomChanged: (value) => setState(
                    () => zoomPanState.displaySettings = zoomPanState
                        .displaySettings
                        .copyWith(zoomLevel: value),
                  ),
                  onInteraction: _autoHideController.resetTimer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDocumentList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Documents in Set List',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.documents.length,
                itemBuilder: (context, index) {
                  final doc = widget.documents[index];
                  final isCurrent = index == _currentDocIndex;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      doc.name,
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${doc.pageCount} pages',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _goToDocument(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
