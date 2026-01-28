import 'package:flutter/material.dart';
import '../models/view_mode.dart';

/// Bottom controls for PDF viewer (page navigation and zoom)
class PdfBottomControls extends StatelessWidget {
  final int currentPage;
  final int? rightPage;
  final int totalPages;
  final double zoomLevel;
  final PdfViewMode viewMode;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onZoomChangeEnd;
  final VoidCallback onInteraction;

  const PdfBottomControls({
    super.key,
    required this.currentPage,
    this.rightPage,
    required this.totalPages,
    required this.zoomLevel,
    this.viewMode = PdfViewMode.single,
    this.onPreviousPage,
    this.onNextPage,
    required this.onZoomChanged,
    required this.onZoomChangeEnd,
    required this.onInteraction,
  });

  String _buildPageText() {
    if (viewMode == PdfViewMode.single || rightPage == null) {
      return 'Page $currentPage of $totalPages';
    }
    return 'Pages $currentPage-$rightPage of $totalPages';
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
              Text(
                _buildPageText(),
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: onNextPage,
              ),
            ],
          ),

          // Zoom slider
          Row(
            children: [
              const Icon(Icons.zoom_out, color: Colors.white, size: 20),
              Expanded(
                child: Slider(
                  value: zoomLevel,
                  min: 0.5,
                  max: 3.0,
                  onChanged: (value) {
                    onZoomChanged(value);
                    onInteraction();
                  },
                  onChangeEnd: onZoomChangeEnd,
                ),
              ),
              const Icon(Icons.zoom_in, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${(zoomLevel * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
