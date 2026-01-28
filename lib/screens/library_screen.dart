import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../widgets/pdf_card.dart';
import 'pdf_viewer_screen.dart';

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

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isGridView = true;
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _syncLibrary();
  }

  Future<void> _syncLibrary() async {
    setState(() => _isLoading = true);
    await PdfService.instance.scanAndSyncLibrary();
    setState(() => _isLoading = false);
  }

  Future<void> _importPdf() async {
    setState(() => _isLoading = true);
    await PdfService.instance.importPdf();
    setState(() => _isLoading = false);
  }

  Future<void> _openPdf(Document document) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(document: document),
      ),
    );

    // Update last opened timestamp
    final updatedDoc = document.copyWith(lastOpened: Value(DateTime.now()));
    await ref.read(databaseProvider).updateDocument(updatedDoc);
  }

  List<Document> _filterDocuments(List<Document> documents) {
    if (_searchQuery.isEmpty) {
      return documents;
    }
    return documents.where((doc) {
      return doc.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
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
              onPressed: _importPdf,
              icon: const Icon(Icons.add),
              label: const Text('Import PDF'),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(List<Document> documents) {
    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          return PdfCard(
            document: documents[index],
            onTap: () => _openPdf(documents[index]),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          return PdfListTile(
            document: documents[index],
            onTap: () => _openPdf(documents[index]),
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
          ElevatedButton(
            onPressed: _syncLibrary,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Score'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
            tooltip: _isGridView ? 'List view' : 'Grid view',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _syncLibrary,
            tooltip: 'Sync library',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _importPdf,
        tooltip: 'Import PDF',
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
      ),
    );
  }
}

/// List tile widget for list view
class PdfListTile extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;

  const PdfListTile({
    super.key,
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, size: 40),
        title: Text(document.name),
        subtitle: Text(
          '${document.pageCount} pages • ${_formatFileSize(document.fileSize)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
