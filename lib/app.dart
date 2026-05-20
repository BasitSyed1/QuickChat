import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/keyboard_dismisser.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/presentation/screens/auth_gate.dart';

class QuickChatApp extends ConsumerWidget {
  const QuickChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final wrapped = child ?? const SizedBox.shrink();
        return KeyboardDismisser(
          child: OfflineBanner(child: wrapped),
        );
      },
      home: const AuthGate(),
    );
  }
}
