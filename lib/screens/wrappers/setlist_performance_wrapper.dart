import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/database.dart';
import '../../router/app_router.dart';
import '../../services/setlist_service.dart';
import '../../widgets/error_placeholder_screen.dart';
import '../setlist_performance_screen.dart';

/// Provider to fetch a setlist with its documents and items by ID
final setListWithDocumentsProvider =
    FutureProvider.family<
      ({SetList? setList, List<Document> documents, List<SetListItem> items}),
      int
    >((ref, id) async {
      final setListService = SetListService();
      final setList = await setListService.getSetList(id);
      final documents = await setListService.getSetListDocuments(id);
      final items = await setListService.getSetListItems(id);
      return (setList: setList, documents: documents, items: items);
    });

/// Wrapper that loads a setlist and its documents before displaying
/// SetListPerformanceScreen. Used for URL-based navigation
/// (e.g., /setlist/7/perform).
class SetListPerformanceWrapper extends ConsumerWidget {
  final int setListId;

  const SetListPerformanceWrapper({super.key, required this.setListId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(setListWithDocumentsProvider(setListId));

    return dataAsync.when(
      data: (data) {
        if (data.setList == null) {
          return ErrorPlaceholderScreen(
            title: context.l10n.setListNotFoundTitle,
            message: context.l10n.setListNotFoundMessage,
            icon: Icons.error_outline,
            buttonLabel: context.l10n.backToSetLists,
            navigateTo: AppRoutes.setlists,
          );
        }

        if (data.documents.isEmpty) {
          return ErrorPlaceholderScreen(
            title: data.setList!.name,
            message: context.l10n.setListHasNoDocuments,
            icon: Icons.music_note_outlined,
            buttonLabel: context.l10n.editSetList,
            navigateTo: AppRoutes.setlistDetailPath(setListId),
          );
        }

        return SetListPerformanceScreen(
          setListId: setListId,
          documents: data.documents,
          items: data.items,
        );
      },
      loading: () => const LoadingScreen(),
      error: (error, stack) => ErrorPlaceholderScreen(
        title: context.l10n.error,
        message: context.l10n.errorLoadingSetList(error.toString()),
        icon: Icons.error_outline,
        iconColor: Colors.red,
        buttonLabel: context.l10n.backToSetLists,
        navigateTo: AppRoutes.setlists,
      ),
    );
  }
}
