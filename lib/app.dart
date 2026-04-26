import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'features/auth/presentation/screens/auth_gate.dart';

class QuickChatApp extends StatelessWidget {
  const QuickChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      home: const AuthGate(),
    );
  }
}
