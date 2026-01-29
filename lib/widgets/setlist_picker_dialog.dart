import 'package:flutter/material.dart';
import '../models/database.dart';
import '../services/setlist_service.dart';

/// Dialog for selecting a set list to add documents to
class SetListPickerDialog extends StatefulWidget {
  const SetListPickerDialog({super.key});

  @override
  State<SetListPickerDialog> createState() => _SetListPickerDialogState();

  /// Shows the dialog and returns the selected set list ID, or null if cancelled
  static Future<int?> show(BuildContext context) {
    return showDialog<int>(
      context: context,
      builder: (context) => const SetListPickerDialog(),
    );
  }
}

class _SetListPickerDialogState extends State<SetListPickerDialog> {
  final _setListService = SetListService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<SetList> _setLists = [];
  bool _isLoading = true;
  int? _selectedId;
  bool _isCreatingNew = false;

  @override
  void initState() {
    super.initState();
    _loadSetLists();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSetLists() async {
    final setLists = await _setListService.getAllSetLists();
    if (mounted) {
      setState(() {
        _setLists = setLists;
        _isLoading = false;
      });
    }
  }

  Future<void> _createAndSelect() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    final description = _descriptionController.text.trim();
    final id = await _setListService.createSetList(
      name,
      description: description.isEmpty ? null : description,
    );

    if (mounted) {
      Navigator.pop(context, id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Set List'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Create new option
                  RadioListTile<int>(
                    value: -1, // Sentinel value for "create new"
                    groupValue: _isCreatingNew ? -1 : _selectedId,
                    onChanged: (value) {
                      setState(() {
                        _isCreatingNew = true;
                        _selectedId = null;
                      });
                    },
                    title: const Text('Create new set list'),
                    secondary: const Icon(Icons.add),
                    selected: _isCreatingNew,
                  ),

                  // New set list fields
                  if (_isCreatingNew) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(),

                  // Existing set lists
                  if (_setLists.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _setLists.length,
                        itemBuilder: (context, index) {
                          final setList = _setLists[index];
                          final description = setList.description;
                          final hasDescription =
                              description != null && description.isNotEmpty;

                          return RadioListTile<int>(
                            value: setList.id,
                            groupValue: _selectedId,
                            onChanged: (value) {
                              setState(() {
                                _selectedId = value;
                                _isCreatingNew = false;
                              });
                            },
                            title: Text(setList.name),
                            subtitle: hasDescription
                                ? Text(
                                    description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                          );
                        },
                      ),
                    )
                  else if (!_isCreatingNew)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No set lists yet. Create one above.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm() ? _confirm : null,
          child: const Text('Add'),
        ),
      ],
    );
  }

  bool _canConfirm() {
    if (_isCreatingNew) {
      return _nameController.text.trim().isNotEmpty;
    }
    return _selectedId != null;
  }

  Future<void> _confirm() async {
    if (_isCreatingNew) {
      await _createAndSelect();
    } else if (_selectedId != null) {
      Navigator.pop(context, _selectedId);
    }
  }
}
