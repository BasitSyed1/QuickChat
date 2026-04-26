import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const primaryColor = Color(0xFF0F0F0F);
  static const primaryVariantColor = Color(0xFF1A1A1A);
  static const primarySoft = Color(0xFF242424);

  // Accent (lime / green)
  static const secondaryColor = Color(0xFF7CFC8A);
  static const secondaryVariantColor = Color(0xFF5EDB72);
  static const secondaryGlow = Color(0xFF6BE675);

  // Backgrounds
  static const backgroundColor = Color(0xFFF6F7F8);
  static const surfaceColor = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF2F3F5);

  // Status
  static const errorColor = Color(0xFFE53935);
  static const successColor = Color(0xFF34C759);
  static const warningColor = Color(0xFFFFB020);

  // Foreground
  static const onPrimaryColor = Color(0xFFFFFFFF);
  static const onSecondaryColor = Color(0xFF000000);
  static const onBackgroundColor = Color(0xFF1C1C1C);
  static const onSurfaceColor = Color(0xFF2A2A2A);
  static const onSurfaceMuted = Color(0xFF7A7A7A);
  static const onErrorColor = Color(0xFFFFFFFF);

  // Chat bubbles
  static const messageIncoming = Color(0xFFEDEDED);
  static const messageOutgoing = Color(0xFF7CFC8A);

  // Lines
  static const dividerColor = Color(0xFFE6E8EB);
  static const borderColor = Color(0xFFE0E3E6);

  // Gradients
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0F0F), Color(0xFF1F1F1F)],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7CFC8A), Color(0xFF5EDB72)],
  );

  // Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: secondaryColor.withValues(alpha: 0.45),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
