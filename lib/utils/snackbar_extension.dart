import 'package:flutter/material.dart';

extension SnackBarExtension on BuildContext {
  void showSnackbar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
  }
}
