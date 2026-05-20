import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/user_prefs.dart';

/// Riverpod-managed theme mode, persisted via [UserPrefs.getThemeMode]. The
/// root MaterialApp watches this provider so the user's choice (system / light
/// / dark) survives restarts.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final raw = await UserPrefs.getThemeMode();
    state = _fromString(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await UserPrefs.setThemeMode(_toString(mode));
  }

  static ThemeMode _fromString(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
