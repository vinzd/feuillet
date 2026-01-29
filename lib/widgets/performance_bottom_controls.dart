import 'package:flutter/material.dart';
import '../models/view_mode.dart';
import 'zoom_slider.dart';

/// Bottom controls for setlist performance mode.
///
/// Provides both document-level and page-level navigation with
/// progress indicators for the current position in the setlist.
class PerformanceBottomControls extends StatelessWidget {
  const PerformanceBottomControls({
    required this.currentDocIndex,
    required this.totalDocs,
    required this.currentDocName,
    required this.currentPage,
    required this.totalPages,
    this.rightPage,
    this.viewMode = PdfViewMode.single,
    this.zoomLevel = 1.0,
    this.onPrevDoc,
    this.onNextDoc,
    this.onPrevPage,
    this.onNextPage,
    this.onZoomChanged,
    this.onInteraction,
    super.key,
  });

  /// Current document index (0-indexed)
  final int currentDocIndex;

  /// Total number of documents in the setlist
  final int totalDocs;

  /// Name of the current document
  final String currentDocName;

  /// Current page number (1-indexed, left page in two-page mode)
  final int currentPage;

  /// Right page number in two-page mode, null for single page
  final int? rightPage;

  /// Total pages in the current document
  final int totalPages;

  /// Current view mode
  final PdfViewMode viewMode;

  /// Current zoom level (0.5 to 3.0)
  final double zoomLevel;

  /// Called when previous document is requested
  final VoidCallback? onPrevDoc;

  /// Called when next document is requested
  final VoidCallback? onNextDoc;

  /// Called when previous page is requested
  final VoidCallback? onPrevPage;

  /// Called when next page is requested
  final VoidCallback? onNextPage;

  /// Called when zoom level changes
  final ValueChanged<double>? onZoomChanged;

  /// Called when user interacts with controls (for auto-hide timer reset)
  final VoidCallback? onInteraction;

  String get _pageText {
    final hasRightPage = viewMode != PdfViewMode.single && rightPage != null;
    return hasRightPage
        ? 'Pages $currentPage-$rightPage of $totalPages'
        : 'Page $currentPage of $totalPages';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white),
                onPressed: currentDocIndex > 0 ? onPrevDoc : null,
                tooltip: 'Previous document',
                iconSize: 28,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      currentDocName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Document ${currentDocIndex + 1} of $totalDocs',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white),
                onPressed: currentDocIndex < totalDocs - 1 ? onNextDoc : null,
                tooltip: 'Next document',
                iconSize: 28,
              ),
            ],
          ),

          const SizedBox(height: 8),

          _DocumentProgressBar(currentIndex: currentDocIndex, total: totalDocs),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: onPrevPage,
                tooltip: 'Previous page',
                iconSize: 32,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 150),
                child: Text(
                  _pageText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: onNextPage,
                tooltip: 'Next page',
                iconSize: 32,
              ),
            ],
          ),

          // Zoom slider
          if (onZoomChanged != null) ...[
            const SizedBox(height: 8),
            ZoomSlider(
              value: zoomLevel,
              onChanged: onZoomChanged!,
              onInteraction: onInteraction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress bar showing document position in setlist
class _DocumentProgressBar extends StatelessWidget {
  const _DocumentProgressBar({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final progress = total > 1 ? (currentIndex + 1) / total : 1.0;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}
