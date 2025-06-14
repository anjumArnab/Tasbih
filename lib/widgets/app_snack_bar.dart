import 'package:flutter/material.dart';

class AppSnackbar {
  static void showSuccess(
    BuildContext context,
    String message, {
    int durationInSeconds = 2,
  }) {
    _show(context, message, Colors.green, durationInSeconds);
  }

  static void showError(
    BuildContext context,
    String message, {
    int durationInSeconds = 3,
  }) {
    _show(context, message, Colors.red, durationInSeconds);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    int durationInSeconds = 3,
  }) {
    _show(context, message, Colors.blue, durationInSeconds);
  }

  static void _show(
    BuildContext context,
    String message,
    Color backgroundColor,
    int durationInSeconds,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: durationInSeconds),
      ),
    );
  }
}
