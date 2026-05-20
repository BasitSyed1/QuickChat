import 'package:flutter/material.dart';

class AvatarPalette {
  static const _palettes = [
    [Color(0xFF5EDB72), Color(0xFF2EA85A)],
    [Color(0xFF6CB7FF), Color(0xFF3D7BD9)],
    [Color(0xFFFFB069), Color(0xFFE07A2A)],
    [Color(0xFFD297FF), Color(0xFF8754E0)],
    [Color(0xFFFF8FA3), Color(0xFFE0526C)],
    [Color(0xFF7CE3D8), Color(0xFF2FA89A)],
  ];

  static List<Color> forKey(String key) {
    if (key.isEmpty) return _palettes[0];
    final hash = key.codeUnits.fold<int>(0, (a, c) => a + c);
    return _palettes[hash % _palettes.length];
  }

  static LinearGradient gradient(String key) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: forKey(key),
    );
  }
}
