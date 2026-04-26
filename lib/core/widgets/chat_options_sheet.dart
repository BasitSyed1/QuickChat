import 'package:flutter/material.dart';

import 'app_bottom_sheet.dart';

class ChatOptionsSheet extends StatelessWidget {
  final VoidCallback? onDelete;
  final VoidCallback? onBlock;

  const ChatOptionsSheet({super.key, this.onDelete, this.onBlock});

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Chat Options',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Chat'),
            onTap: () {
              Navigator.pop(context);
              onDelete?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Block User'),
            onTap: () {
              Navigator.pop(context);
              onBlock?.call();
            },
          ),
        ],
      ),
    );
  }
}
