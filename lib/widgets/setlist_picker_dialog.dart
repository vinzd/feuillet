import 'package:flutter/material.dart';
import '../l10n/l10n_extension.dart';
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

/// Sentinel value used to indicate "Create new set list" option
const int _createNewSentinel = -1;

class _SetListPickerDialogState extends State<SetListPickerDialog> {
  final _setListService = SetListService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<SetList> _setLists = [];
  bool _isLoading = true;
  int? _selectedValue; // -1 for create new, positive IDs for existing lists

  bool get _isCreatingNew => _selectedValue == _createNewSentinel;

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

  void _onSelectionChanged(int? value) {
    setState(() {
      _selectedValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.addToSetList),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : RadioGroup<int>(
                groupValue: _selectedValue,
                onChanged: _onSelectionChanged,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Create new option
                    RadioListTile<int>(
                      value: _createNewSentinel,
                      title: Text(context.l10n.createNewSetList),
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
                              decoration: InputDecoration(
                                labelText: context.l10n.name,
                                border: OutlineInputBorder(),
                              ),
                              autofocus: true,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: context.l10n.descriptionOptional,
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
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          context.l10n.noSetListsYetCreateAbove,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _canConfirm() ? _confirm : null,
          child: Text(context.l10n.add),
        ),
      ],
    );
  }

  bool _canConfirm() {
    if (_isCreatingNew) {
      return _nameController.text.trim().isNotEmpty;
    }
    return _selectedValue != null && _selectedValue != _createNewSentinel;
  }

  Future<void> _confirm() async {
    if (_isCreatingNew) {
      await _createAndSelect();
    } else if (_selectedValue != null) {
      Navigator.pop(context, _selectedValue);
    }
  }
}
