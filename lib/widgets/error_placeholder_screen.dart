import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A reusable error/placeholder screen for displaying messages with an action button.
/// Used for not-found pages, empty states, and error states throughout the app.
class ErrorPlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? iconColor;
  final String buttonLabel;
  final String navigateTo;

  const ErrorPlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.iconColor,
    required this.buttonLabel,
    required this.navigateTo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(navigateTo),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple loading screen with a centered progress indicator.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
