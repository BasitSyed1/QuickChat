import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only per-device user preferences. Keeps things like the user's
/// chosen status message, blocked-user IDs and app settings on-device without
/// requiring a backend schema migration. Each helper is best-effort and silently
/// falls back if persistent storage is unavailable.
class UserPrefs {
  UserPrefs._();

  static const _statusKey = 'profile_status_v1';
  static const _statusEmojiKey = 'profile_status_emoji_v1';
  static const _blockedKey = 'blocked_user_ids_v1';

  // Settings toggles
  static const _notifPushKey = 'settings_push_v1';
  static const _notifSoundKey = 'settings_sound_v1';
  static const _notifVibKey = 'settings_vibration_v1';
  static const _readReceiptsKey = 'settings_read_receipts_v1';
  static const _lastSeenVisibleKey = 'settings_last_seen_visible_v1';
  static const _enterToSendKey = 'settings_enter_to_send_v1';
  static const _themeModeKey = 'settings_theme_mode_v1';

  // Per-conversation flags
  static const _pinnedKey = 'pinned_conversation_ids_v1';
  static const _mutedKey = 'muted_conversation_ids_v1';
  static const _archivedKey = 'archived_conversation_ids_v1';
  static const _wallpaperKey = 'chat_wallpaper_v1';

  // Per-message
  static const _starredKey = 'starred_message_ids_v1';
  static const _reactionsKey = 'message_reactions_v1';

  // ===== Status =====

  static const defaultStatus = 'Hey there! I am using QuickChat.';

  static const quickStatuses = <String>[
    'Available',
    'Busy',
    'At school',
    'At work',
    'Battery about to die',
    'Can\'t talk, QuickChat only',
    'In a meeting',
    'At the gym',
    'Sleeping',
    'Urgent calls only',
  ];

  static Future<String> getStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_statusKey) ?? defaultStatus;
    } catch (_) {
      return defaultStatus;
    }
  }

  static Future<String> getStatusEmoji() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_statusEmojiKey) ?? '💬';
    } catch (_) {
      return '💬';
    }
  }

  static Future<void> setStatus(String value, {String? emoji}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, value);
      if (emoji != null) {
        await prefs.setString(_statusEmojiKey, emoji);
      }
    } catch (_) {/* best-effort */}
  }

  // ===== Blocked users =====

  static Future<Set<String>> blockedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_blockedKey) ?? const <String>[]).toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  static Future<bool> isBlocked(String userId) async {
    final ids = await blockedIds();
    return ids.contains(userId);
  }

  static Future<void> block(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(_blockedKey) ?? <String>[]).toList();
      if (!list.contains(userId)) {
        list.add(userId);
        await prefs.setStringList(_blockedKey, list);
      }
    } catch (_) {/* best-effort */}
  }

  static Future<void> unblock(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(_blockedKey) ?? <String>[]).toList();
      list.remove(userId);
      await prefs.setStringList(_blockedKey, list);
    } catch (_) {/* best-effort */}
  }

  // ===== Settings =====

  static Future<bool> _readBool(String key, {bool defaultValue = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }

  static Future<void> _writeBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {/* best-effort */}
  }

  static Future<bool> isPushOn() => _readBool(_notifPushKey);
  static Future<void> setPush(bool v) => _writeBool(_notifPushKey, v);

  static Future<bool> isSoundOn() => _readBool(_notifSoundKey);
  static Future<void> setSound(bool v) => _writeBool(_notifSoundKey, v);

  static Future<bool> isVibrationOn() => _readBool(_notifVibKey);
  static Future<void> setVibration(bool v) => _writeBool(_notifVibKey, v);

  static Future<bool> isReadReceiptsOn() => _readBool(_readReceiptsKey);
  static Future<void> setReadReceipts(bool v) => _writeBool(_readReceiptsKey, v);

  static Future<bool> isLastSeenVisible() => _readBool(_lastSeenVisibleKey);
  static Future<void> setLastSeenVisible(bool v) =>
      _writeBool(_lastSeenVisibleKey, v);

  static Future<bool> isEnterToSendOn() =>
      _readBool(_enterToSendKey, defaultValue: false);
  static Future<void> setEnterToSend(bool v) => _writeBool(_enterToSendKey, v);

  // ===== Theme =====

  /// 'system' (default), 'light', or 'dark'.
  static Future<String> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_themeModeKey) ?? 'system';
    } catch (_) {
      return 'system';
    }
  }

  static Future<void> setThemeMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode);
    } catch (_) {/* best-effort */}
  }

  // ===== Conversation flags (pin / mute / archive) =====

  static Future<Set<String>> _idSet(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(key) ?? const <String>[]).toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  static Future<void> _addId(String key, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(key) ?? <String>[]).toList();
      if (!list.contains(id)) {
        list.add(id);
        await prefs.setStringList(key, list);
      }
    } catch (_) {/* best-effort */}
  }

  static Future<void> _removeId(String key, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(key) ?? <String>[]).toList();
      list.remove(id);
      await prefs.setStringList(key, list);
    } catch (_) {/* best-effort */}
  }

  static Future<Set<String>> pinnedConversations() => _idSet(_pinnedKey);
  static Future<bool> isPinned(String cid) async =>
      (await pinnedConversations()).contains(cid);
  static Future<void> pin(String cid) => _addId(_pinnedKey, cid);
  static Future<void> unpin(String cid) => _removeId(_pinnedKey, cid);

  static Future<Set<String>> mutedConversations() => _idSet(_mutedKey);
  static Future<bool> isMuted(String cid) async =>
      (await mutedConversations()).contains(cid);
  static Future<void> mute(String cid) => _addId(_mutedKey, cid);
  static Future<void> unmute(String cid) => _removeId(_mutedKey, cid);

  static Future<Set<String>> archivedConversations() => _idSet(_archivedKey);
  static Future<bool> isArchived(String cid) async =>
      (await archivedConversations()).contains(cid);
  static Future<void> archive(String cid) => _addId(_archivedKey, cid);
  static Future<void> unarchive(String cid) => _removeId(_archivedKey, cid);

  // ===== Wallpaper =====

  /// Stored as a single int index into the AppWallpapers list, default 0.
  static Future<int> getWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_wallpaperKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> setWallpaper(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_wallpaperKey, index);
    } catch (_) {/* best-effort */}
  }

  // ===== Starred messages =====

  static Future<Set<String>> starredMessageIds() => _idSet(_starredKey);
  static Future<bool> isStarred(String id) async =>
      (await starredMessageIds()).contains(id);
  static Future<void> star(String id) => _addId(_starredKey, id);
  static Future<void> unstar(String id) => _removeId(_starredKey, id);

  // ===== Message reactions =====

  /// Returns a map of messageId → list of emojis.
  static Future<Map<String, List<String>>> reactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reactionsKey);
      if (raw == null || raw.isEmpty) return <String, List<String>>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, List<String>>{};
      return decoded.map<String, List<String>>((k, v) {
        final list = (v as List?)?.whereType<String>().toList() ?? <String>[];
        return MapEntry('$k', list);
      });
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  static Future<List<String>> reactionsFor(String messageId) async {
    final all = await reactions();
    return all[messageId] ?? const <String>[];
  }

  /// Toggle a reaction emoji on a message. If the emoji already exists for
  /// this message it is removed; otherwise it is added.
  static Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await reactions();
      final list = List<String>.from(all[messageId] ?? const <String>[]);
      if (list.contains(emoji)) {
        list.remove(emoji);
      } else {
        list.add(emoji);
      }
      if (list.isEmpty) {
        all.remove(messageId);
      } else {
        all[messageId] = list;
      }
      await prefs.setString(_reactionsKey, jsonEncode(all));
    } catch (_) {/* best-effort */}
  }

  static Future<void> clearReactions(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await reactions();
      if (all.remove(messageId) != null) {
        await prefs.setString(_reactionsKey, jsonEncode(all));
      }
    } catch (_) {/* best-effort */}
  }
}
