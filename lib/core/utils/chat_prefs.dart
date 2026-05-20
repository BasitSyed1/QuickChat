import 'package:shared_preferences/shared_preferences.dart';

class ChatPrefs {
  static const _prefix = 'last_seen_';

  static Future<DateTime?> lastSeen(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$conversationId');
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, DateTime>> lastSeenAll(
    Iterable<String> conversationIds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final out = <String, DateTime>{};
      for (final id in conversationIds) {
        final raw = prefs.getString('$_prefix$id');
        if (raw == null) continue;
        final at = DateTime.tryParse(raw);
        if (at != null) out[id] = at;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static Future<void> markSeen(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix$conversationId',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      // best-effort; if storage isn't available, just skip
    }
  }

  static const _welcomeKey = 'dashboard_welcome_dismissed_v1';

  static Future<bool> isWelcomeDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_welcomeKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> dismissWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeKey, true);
    } catch (_) {/* best-effort */}
  }
}
