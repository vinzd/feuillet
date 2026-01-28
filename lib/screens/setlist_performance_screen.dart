import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../models/database.dart';

/// Performance mode for set lists with quick navigation
class SetListPerformanceScreen extends StatefulWidget {
  final int setListId;
  final List<Document> documents;

  const SetListPerformanceScreen({
    super.key,
    required this.setListId,
    required this.documents,
  });

  @override
  State<SetListPerformanceScreen> createState() => _SetListPerformanceScreenState();
}

class _SetListPerformanceScreenState extends State<SetListPerformanceScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, PdfController> _pdfControllers = {};
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializePdfControllers();
  }

  Future<void> _initializePdfControllers() async {
    for (int i = 0; i < widget.documents.length; i++) {
      final doc = widget.documents[i];

      // Use bytes on web, file path on native
      final Future<PdfDocument> pdfDocument;
      if (doc.pdfBytes != null) {
        pdfDocument = PdfDocument.openData(doc.pdfBytes!);
      } else {
        pdfDocument = PdfDocument.openFile(doc.filePath);
      }

      _pdfControllers[i] = PdfController(document: pdfDocument);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _pdfControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _nextDocument() {
    if (_currentIndex < widget.documents.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousDocument() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToDocument(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() => _showControls = !_showControls);
        },
        child: Stack(
          children: [
            // PDF page view
            PageView.builder(
              controller: _pageController,
              itemCount: widget.documents.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final pdfController = _pdfControllers[index];
                if (pdfController == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return PdfView(
                  controller: pdfController,
                  scrollDirection: Axis.horizontal,
                  pageSnapping: true,
                );
              },
            ),

            // Top controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.black.withOpacity(0.7),
                title: Text(
                  widget.documents[_currentIndex].name,
                  style: const TextStyle(color: Colors.white),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.list),
                    onPressed: _showDocumentList,
                    tooltip: 'Document list',
                  ),
                ],
              ),
            ),

            // Bottom navigation
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.7),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentIndex + 1} of ${widget.documents.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Navigation buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 36),
                          color: Colors.white,
                          onPressed: _currentIndex > 0 ? _previousDocument : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 48),
                          color: Colors.white,
                          onPressed: _currentIndex > 0 ? _previousDocument : null,
                        ),
                        Container(
                          width: 80,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (widget.documents.length > 1)
                                ? (_currentIndex + 1) / widget.documents.length
                                : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 48),
                          color: Colors.white,
                          onPressed: _currentIndex < widget.documents.length - 1
                              ? _nextDocument
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 36),
                          color: Colors.white,
                          onPressed: _currentIndex < widget.documents.length - 1
                              ? _nextDocument
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                  final isCurrent = index == _currentIndex;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? Colors.blue : Colors.grey,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      doc.name,
                      style: TextStyle(
                        color: isCurrent ? Colors.blue : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
