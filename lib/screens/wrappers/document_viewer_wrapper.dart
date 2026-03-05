import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers/document_providers.dart';
import '../../router/app_router.dart';
import '../../services/database_service.dart';
import '../../widgets/error_placeholder_screen.dart';
import '../document_viewer_screen.dart';

/// Wrapper that loads a document by ID before displaying DocumentViewerScreen.
/// Used for URL-based navigation (e.g., /document/42).
class DocumentViewerWrapper extends ConsumerStatefulWidget {
  final int documentId;

  const DocumentViewerWrapper({super.key, required this.documentId});

  @override
  ConsumerState<DocumentViewerWrapper> createState() =>
      _DocumentViewerWrapperState();
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
            title: context.l10n.documentNotFound,
            message: context.l10n.documentNotFoundMessage,
            icon: Icons.error_outline,
            buttonLabel: context.l10n.backToLibrary,
            navigateTo: AppRoutes.library,
          );
        }
        return DocumentViewerScreen(document: document);
      },
      loading: () => const LoadingScreen(),
      error: (error, stack) => ErrorPlaceholderScreen(
        title: context.l10n.error,
        message: context.l10n.errorLoadingDocument(error.toString()),
        icon: Icons.error_outline,
        iconColor: Colors.red,
        buttonLabel: context.l10n.backToLibrary,
        navigateTo: AppRoutes.library,
      ),
    );
  }
}
