import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight on-device cache backed by Hive. Stores cheap snapshots of the
/// dashboard and per-conversation message lists so cold opens render instantly
/// while the live data refreshes in the background.
class LocalCache {
  LocalCache._();

  static const _dashBox = 'qc_dashboard_v1';
  static const _msgsBox = 'qc_messages_v1';

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await Hive.initFlutter();
      await Hive.openBox(_dashBox);
      await Hive.openBox(_msgsBox);
      _ready = true;
    } catch (_) {
      // Cache is best-effort; fall through to no-op getters/setters.
    }
  }

  static Box? get _dash {
    if (!_ready) return null;
    return Hive.isBoxOpen(_dashBox) ? Hive.box(_dashBox) : null;
  }

  static Box? get _msgs {
    if (!_ready) return null;
    return Hive.isBoxOpen(_msgsBox) ? Hive.box(_msgsBox) : null;
  }

  // === Dashboard ===

  static Map<String, dynamic>? loadDashboard(String userId) {
    final raw = _dash?.get('dash:$userId');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static Future<void> saveDashboard(
    String userId,
    Map<String, dynamic> json,
  ) async {
    await _dash?.put('dash:$userId', _sanitize(json));
  }

  // === Messages ===

  static List<Map<String, dynamic>>? loadMessages(String cid) {
    final raw = _msgs?.get(cid);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    }
    return null;
  }

  static Future<void> saveMessages(
    String cid,
    List<Map<String, dynamic>> data,
  ) async {
    final box = _msgs;
    if (box == null) return;
    final trimmed = data.length > 300 ? data.sublist(data.length - 300) : data;
    await box.put(cid, trimmed.map(_sanitize).toList(growable: false));
  }

  // === housekeeping ===

  static Future<void> clearAll() async {
    await _dash?.clear();
    await _msgs?.clear();
  }

  /// Hive accepts primitives, lists and string-keyed maps. Recursively coerce
  /// to keep stored data deserialization-safe.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((k, v) {
      out[k] = _coerce(v);
    });
    return out;
  }

  static dynamic _coerce(Object? value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      final m = <String, dynamic>{};
      value.forEach((k, v) => m['$k'] = _coerce(v));
      return m;
    }
    if (value is List) return value.map(_coerce).toList(growable: false);
    return value.toString();
  }
}
