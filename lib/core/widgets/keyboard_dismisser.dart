import 'package:flutter/material.dart';

/// Wraps a subtree so that any tap outside a focused TextField dismisses
/// the soft keyboard with the smooth iOS-style behavior.
class KeyboardDismisser extends StatelessWidget {
  final Widget child;
  const KeyboardDismisser({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
