import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/database.dart';
import '../services/database_service.dart';
import '../services/setlist_service.dart';
import 'setlist_detail_screen.dart';

/// Provider for set lists
final setListsProvider = StreamProvider<List<SetList>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchAllSetLists();
});

/// Screen showing all set lists
class SetListsScreen extends ConsumerStatefulWidget {
  const SetListsScreen({super.key});

  @override
  ConsumerState<SetListsScreen> createState() => _SetListsScreenState();
}

class _SetListsScreenState extends ConsumerState<SetListsScreen> {
  final _setListService = SetListService();

  Future<void> _createSetList() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Set List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'name': nameController.text,
                  'description': descController.text,
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      final id = await _setListService.createSetList(
        result['name']!,
        description: result['description'],
      );

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SetListDetailScreen(setListId: id),
          ),
        );
      }
    }
  }

  Future<void> _deleteSetList(SetList setList) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Set List'),
        content: Text('Are you sure you want to delete "${setList.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _setListService.deleteSetList(setList.id);
    }
  }

  Future<void> _duplicateSetList(SetList setList) async {
    await _setListService.duplicateSetList(setList.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set list duplicated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setListsAsync = ref.watch(setListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Lists'),
      ),
      body: setListsAsync.when(
        data: (setLists) {
          if (setLists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music_outlined,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No set lists yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _createSetList,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Set List'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: setLists.length,
            itemBuilder: (context, index) {
              final setList = setLists[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.queue_music),
                  ),
                  title: Text(setList.name),
                  subtitle: setList.description != null &&
                          setList.description!.isNotEmpty
                      ? Text(
                          setList.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'duplicate':
                          _duplicateSetList(setList);
                          break;
                        case 'delete':
                          _deleteSetList(setList);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy),
                            SizedBox(width: 8),
                            Text('Duplicate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SetListDetailScreen(setListId: setList.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading set lists: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSetList,
        tooltip: 'New Set List',
        child: const Icon(Icons.add),
      ),
    );
  }
}
