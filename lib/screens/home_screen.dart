import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';

/// Home screen with bottom navigation.
/// Uses ShellRoute from go_router to display Library or SetLists based on URL.
class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final Widget? child;

  const HomeScreen({super.key, this.initialIndex = 0, this.child});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          context.go(index == 0 ? AppRoutes.library : AppRoutes.setlists);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.library_music_outlined),
            selectedIcon: const Icon(Icons.library_music),
            label: context.l10n.library,
          ),
          NavigationDestination(
            icon: const Icon(Icons.queue_music_outlined),
            selectedIcon: const Icon(Icons.queue_music),
            label: context.l10n.setLists,
          ),
        ],
      ),
    );
  }
}
