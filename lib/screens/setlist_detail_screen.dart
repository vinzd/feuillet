import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/database.dart';
import '../router/app_router.dart';
import '../services/database_service.dart';
import '../services/setlist_service.dart';

/// Screen for viewing and editing a set list
class SetListDetailScreen extends StatefulWidget {
  final int setListId;

  const SetListDetailScreen({super.key, required this.setListId});

  @override
  State<SetListDetailScreen> createState() => _SetListDetailScreenState();
}

class _SetListDetailScreenState extends State<SetListDetailScreen> {
  final _setListService = SetListService();
  final _database = DatabaseService.instance.database;

  SetList? _setList;
  List<Document> _documents = [];
  List<SetListItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSetList();
  }

  Future<void> _loadSetList() async {
    setState(() => _isLoading = true);

    _setList = await _setListService.getSetList(widget.setListId);
    _documents = await _setListService.getSetListDocuments(widget.setListId);
    _items = await _setListService.getSetListItems(widget.setListId);

    setState(() => _isLoading = false);
  }

  Future<void> _addDocuments() async {
    final allDocuments = await _database.getAllDocuments();
    final currentDocIds = _documents.map((d) => d.id).toSet();
    final availableDocs =
        allDocuments.where((d) => !currentDocIds.contains(d.id)).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    if (availableDocs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All documents are already in this set list'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final selected = await showDialog<List<int>>(
      context: context,
      builder: (context) => _DocumentPickerDialog(documents: availableDocs),
    );

    if (selected != null && selected.isNotEmpty) {
      for (final docId in selected) {
        await _setListService.addDocumentToSetList(
          setListId: widget.setListId,
          documentId: docId,
        );
      }
      await _setListService.touchSetList(widget.setListId);
      await _loadSetList();
    }
  }

  Future<void> _removeDocument(int itemId) async {
    await _setListService.removeDocumentFromSetList(itemId);
    await _setListService.touchSetList(widget.setListId);
    await _loadSetList();
  }

  Future<void> _reorderDocuments(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);

    final itemIds = _items.map((i) => i.id).toList();
    await _setListService.reorderSetListItems(widget.setListId, itemIds);
    await _setListService.touchSetList(widget.setListId);
    await _loadSetList();
  }

  Future<void> _startPerformance() async {
    if (_documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add documents to start performance mode'),
        ),
      );
      return;
    }

    context.push(AppRoutes.setlistPerformancePath(widget.setListId));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Set List')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_setList == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Set List')),
        body: const Center(child: Text('Set list not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_setList!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _startPerformance,
            tooltip: 'Start performance',
          ),
        ],
      ),
      body: Column(
        children: [
          // Description card
          if (_setList!.description != null &&
              _setList!.description!.isNotEmpty)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_setList!.description!),
              ),
            ),

          // Documents list
          Expanded(
            child: _documents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_note_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        const Text('No documents in this set list'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _addDocuments,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Documents'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _documents.length,
                    onReorder: _reorderDocuments,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      final item = _items[index];

                      return Card(
                        key: ValueKey(doc.id),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(doc.name),
                          subtitle: Text('${doc.pageCount} pages'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () {
                                  context.push(AppRoutes.documentPath(doc.id));
                                },
                                tooltip: 'View',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeDocument(item.id),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocuments,
        tooltip: 'Add Documents',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog for selecting documents to add to set list
class _DocumentPickerDialog extends StatefulWidget {
  final List<Document> documents;

  const _DocumentPickerDialog({required this.documents});

  @override
  State<_DocumentPickerDialog> createState() => _DocumentPickerDialogState();
}

class _DocumentPickerDialogState extends State<_DocumentPickerDialog> {
  final Set<int> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Documents'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.documents.length,
          itemBuilder: (context, index) {
            final doc = widget.documents[index];
            final isSelected = _selectedIds.contains(doc.id);

            return CheckboxListTile(
              title: Text(doc.name),
              subtitle: Text('${doc.pageCount} pages'),
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(doc.id);
                  } else {
                    _selectedIds.remove(doc.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIds.toList()),
          child: Text('Add (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
