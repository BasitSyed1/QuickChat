import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Centralized iOS-styled dialogs and toasts so destructive actions, errors
/// and confirmations look consistent everywhere in the app.
class AppDialogs {
  AppDialogs._();

  /// Yes/No confirmation. Returns `true` when the user accepted.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: message == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13.5, height: 1.35),
                ),
              ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              cancelLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            isDefaultAction: !destructive,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Single-action info/error dialog.
  static Future<void> info(
    BuildContext context, {
    required String title,
    String? message,
    String okLabel = 'OK',
  }) {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: message == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13.5, height: 1.35),
                ),
              ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              okLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show a quick toast-style snackbar with a leading icon.
  static void toast(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color? color,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AppColors.primaryColor,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }
}
