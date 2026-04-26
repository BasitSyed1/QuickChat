import 'package:flutter/material.dart';

class AppSheets {
  static Future<T?> show<T>(BuildContext context, Widget sheet) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: sheet,
      ),
    );
  }
}
