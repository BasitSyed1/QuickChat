import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Lightweight predefined chat-background palettes. Each entry is a name +
/// gradient pair; the chat screen paints them behind the message list when the
/// user picks one from the chat header menu.
class ChatWallpapers {
  ChatWallpapers._();

  static const palettes = <ChatWallpaper>[
    ChatWallpaper(
      name: 'Default',
      colors: [Color(0xFFF2F3F5), Color(0xFFFFFFFF)],
    ),
    ChatWallpaper(
      name: 'Lime',
      colors: [Color(0xFFEAFBE9), Color(0xFFD6F5DC)],
    ),
    ChatWallpaper(
      name: 'Sunset',
      colors: [Color(0xFFFFE0CC), Color(0xFFFFC1B6)],
    ),
    ChatWallpaper(
      name: 'Ocean',
      colors: [Color(0xFFD3E6FB), Color(0xFFBAD8F7)],
    ),
    ChatWallpaper(
      name: 'Lavender',
      colors: [Color(0xFFE7DDFD), Color(0xFFD1C0F8)],
    ),
    ChatWallpaper(
      name: 'Midnight',
      colors: [Color(0xFF1B2438), Color(0xFF0F1421)],
      dark: true,
    ),
    ChatWallpaper(
      name: 'Carbon',
      colors: [Color(0xFF181818), Color(0xFF2A2A2A)],
      dark: true,
    ),
  ];

  static ChatWallpaper byIndex(int i) {
    if (i < 0 || i >= palettes.length) return palettes.first;
    return palettes[i];
  }
}

class ChatWallpaper {
  final String name;
  final List<Color> colors;
  final bool dark;

  const ChatWallpaper({
    required this.name,
    required this.colors,
    this.dark = false,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );

  /// Returns the recommended pattern color (the subtle background icon tint)
  /// for this wallpaper.
  Color patternColor() {
    if (dark) return Colors.white.withValues(alpha: 0.04);
    return AppColors.onSurfaceMuted.withValues(alpha: 0.05);
  }
}
