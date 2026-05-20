import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceSnapshot {
  final Set<String> onlineIds;
  final Map<String, DateTime> lastSeen;
  const PresenceSnapshot({
    required this.onlineIds,
    required this.lastSeen,
  });

  static const empty =
      PresenceSnapshot(onlineIds: <String>{}, lastSeen: <String, DateTime>{});
}

class PresenceService {
  PresenceService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  RealtimeChannel? _usersChannel;
  Timer? _heartbeat;
  final _controller = StreamController<PresenceSnapshot>.broadcast();
  Set<String> _online = const <String>{};
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};

  Stream<PresenceSnapshot> get snapshots => _controller.stream;

  Future<void> connect() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (_channel != null) return;

    await _hydrateLastSeen();
    await _writeLastSeen();
    _heartbeat ??= Timer.periodic(
      const Duration(seconds: 50),
      (_) => _writeLastSeen(),
    );

    try {
      final channel = _supabase.channel(
        'presence:lobby',
        opts: RealtimeChannelConfig(key: user.id),
      );

      channel
          .onPresenceSync((_) => _emitOnline(channel))
          .onPresenceJoin((_) => _emitOnline(channel))
          .onPresenceLeave((_) => _emitOnline(channel))
          .subscribe((status, _) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await channel.track({
              'user_id': user.id,
              'online_at': DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {/* ignore */}
        }
      });

      _channel = channel;

      // Subscribe to users.last_seen updates so the chat header refreshes
      // without polling.
      try {
        final usersChannel = _supabase
            .channel('public:users:last_seen')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'users',
              callback: (payload) {
                final row = payload.newRecord;
                final id = row['id'] as String?;
                final raw = row['last_seen'] as String?;
                if (id == null || raw == null) return;
                final at = DateTime.tryParse(raw);
                if (at == null) return;
                _lastSeen[id] = at;
                _emitSnapshot();
              },
            )
            .subscribe();
        _usersChannel = usersChannel;
      } catch (_) {/* ignore */}
    } catch (_) {
      // presence is non-critical
    }
  }

  Future<void> _hydrateLastSeen() async {
    try {
      final rows = await _supabase
          .from('users')
          .select('id, last_seen');
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String?;
        final raw = m['last_seen'] as String?;
        if (id == null || raw == null) continue;
        final at = DateTime.tryParse(raw);
        if (at != null) _lastSeen[id] = at;
      }
      _emitSnapshot();
    } catch (_) {/* ignore */}
  }

  Future<void> _writeLastSeen() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase
          .from('users')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id);
    } catch (_) {/* best-effort */}
  }

  void _emitOnline(RealtimeChannel channel) {
    try {
      final state = channel.presenceState();
      final ids = <String>{};
      for (final p in state) {
        for (final presence in p.presences) {
          final payload = presence.payload;
          final id = payload['user_id'];
          if (id is String) ids.add(id);
        }
      }
      _online = ids;
      // refresh last seen for everyone currently online
      final now = DateTime.now().toUtc();
      for (final id in ids) {
        _lastSeen[id] = now;
      }
      _emitSnapshot();
    } catch (_) {/* ignore */}
  }

  void _emitSnapshot() {
    if (_controller.isClosed) return;
    _controller.add(PresenceSnapshot(
      onlineIds: Set.unmodifiable(_online),
      lastSeen: Map.unmodifiable(_lastSeen),
    ));
  }

  Future<void> markOffline() async {
    await _writeLastSeen();
  }

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _writeLastSeen();
    final c = _channel;
    _channel = null;
    if (c != null) {
      try {
        await c.untrack();
      } catch (_) {/* ignore */}
      try {
        await _supabase.removeChannel(c);
      } catch (_) {/* ignore */}
    }
    final u = _usersChannel;
    _usersChannel = null;
    if (u != null) {
      try {
        await _supabase.removeChannel(u);
      } catch (_) {/* ignore */}
    }
  }

  void dispose() {
    disconnect();
    if (!_controller.isClosed) _controller.close();
  }
}
