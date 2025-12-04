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

  static void showActivityStatus(
    BuildContext context,
    String message, {
    int durationInSeconds = 3,
  }) {
    _show(
      context,
      message,
      Color(0xFF0F4C75),
      durationInSeconds,
      behavior: SnackBarBehavior.floating,
      shapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  static void _show(
    BuildContext context,
    String message,
    Color backgroundColor,
    int durationInSeconds, {
    SnackBarBehavior? behavior,
    ShapeBorder? shapeBorder,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: durationInSeconds),
        behavior: behavior,
        shape: shapeBorder,
      ),
    );
  }
}
