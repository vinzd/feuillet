import 'package:flutter/material.dart';
import '../models/view_mode.dart';
import 'zoom_slider.dart';

/// Bottom controls for PDF viewer (page navigation and zoom)
class PdfBottomControls extends StatelessWidget {
  const PdfBottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.zoomLevel,
    required this.onZoomChanged,
    required this.onInteraction,
    this.rightPage,
    this.viewMode = PdfViewMode.single,
    this.onPreviousPage,
    this.onNextPage,
    this.onZoomChangeEnd,
    super.key,
  });

  final int currentPage;
  final int? rightPage;
  final int totalPages;
  final double zoomLevel;
  final PdfViewMode viewMode;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double>? onZoomChangeEnd;
  final VoidCallback onInteraction;

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
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: onPreviousPage,
              ),
              Text(_pageText, style: const TextStyle(color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: onNextPage,
              ),
            ],
          ),

          // Zoom slider
          ZoomSlider(
            value: zoomLevel,
            onChanged: onZoomChanged,
            onChangeEnd: onZoomChangeEnd,
            onInteraction: onInteraction,
            width: MediaQuery.of(context).size.width - 150,
          ),
        ],
      ),
    );
  }
}
