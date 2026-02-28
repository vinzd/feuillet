import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../router/app_router.dart';
import '../../services/database_service.dart';
import '../../widgets/error_placeholder_screen.dart';
import '../document_viewer_screen.dart';

/// Provider to fetch a document by ID
final documentByIdProvider = FutureProvider.family<Document?, int>((
  ref,
  id,
) async {
  final db = ref.read(databaseProvider);
  return db.getDocument(id);
});

/// Wrapper that loads a document by ID before displaying DocumentViewerScreen.
/// Used for URL-based navigation (e.g., /document/42).
class DocumentViewerWrapper extends ConsumerStatefulWidget {
  final int documentId;

  const DocumentViewerWrapper({super.key, required this.documentId});

  @override
  ConsumerState<DocumentViewerWrapper> createState() => _DocumentViewerWrapperState();
}

class _DocumentViewerWrapperState extends ConsumerState<DocumentViewerWrapper> {
  @override
  void initState() {
    super.initState();
    _updateLastOpened();
  }

  Future<void> _updateLastOpened() async {
    final db = ref.read(databaseProvider);
    final document = await db.getDocument(widget.documentId);
    if (document != null) {
      final updatedDoc = document.copyWith(lastOpened: Value(DateTime.now()));
      await db.updateDocument(updatedDoc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentAsync = ref.watch(documentByIdProvider(widget.documentId));

    return documentAsync.when(
      data: (document) {
        if (document == null) {
          return ErrorPlaceholderScreen(
            title: 'Document Not Found',
            message: 'This document could not be found.',
            icon: Icons.error_outline,
            buttonLabel: 'Back to Library',
            navigateTo: AppRoutes.library,
          );
        }
        return DocumentViewerScreen(document: document);
      },
      loading: () => const LoadingScreen(),
      error: (error, stack) => ErrorPlaceholderScreen(
        title: 'Error',
        message: 'Error loading document: $error',
        icon: Icons.error_outline,
        iconColor: Colors.red,
        buttonLabel: 'Back to Library',
        navigateTo: AppRoutes.library,
      ),
    );
  }
}
