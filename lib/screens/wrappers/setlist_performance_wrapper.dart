import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../router/app_router.dart';
import '../../services/setlist_service.dart';
import '../../widgets/error_placeholder_screen.dart';
import '../setlist_performance_screen.dart';

/// Provider to fetch a setlist with its documents by ID
final setListWithDocumentsProvider =
    FutureProvider.family<({SetList? setList, List<Document> documents}), int>((
      ref,
      id,
    ) async {
      final setListService = SetListService();
      final setList = await setListService.getSetList(id);
      final documents = await setListService.getSetListDocuments(id);
      return (setList: setList, documents: documents);
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
            title: 'Set List Not Found',
            message: 'This set list could not be found.',
            icon: Icons.error_outline,
            buttonLabel: 'Back to Set Lists',
            navigateTo: AppRoutes.setlists,
          );
        }

        if (data.documents.isEmpty) {
          return ErrorPlaceholderScreen(
            title: data.setList!.name,
            message: 'This set list has no documents.',
            icon: Icons.music_note_outlined,
            buttonLabel: 'Edit Set List',
            navigateTo: AppRoutes.setlistDetailPath(setListId),
          );
        }

        return SetListPerformanceScreen(
          setListId: setListId,
          documents: data.documents,
        );
      },
      loading: () => const LoadingScreen(),
      error: (error, stack) => ErrorPlaceholderScreen(
        title: 'Error',
        message: 'Error loading set list: $error',
        icon: Icons.error_outline,
        iconColor: Colors.red,
        buttonLabel: 'Back to Set Lists',
        navigateTo: AppRoutes.setlists,
      ),
    );
  }
}
