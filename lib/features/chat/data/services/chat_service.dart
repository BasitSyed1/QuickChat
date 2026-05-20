import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/cache/local_cache.dart';
import '../../../../core/utils/message_crypto.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../domain/entities/chat_preview.dart';

class ChatService {
  ChatService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Cached negative result so we don't keep re-querying columns that aren't
  /// present (e.g. before the production migration in tools/schema.sql has
  /// been applied). Each flag flips to `false` the moment Supabase tells us
  /// the column doesn't exist; the rich features then no-op cleanly.
  static bool _convoClearColumns = true;
  static bool _messageReceiptColumns = true;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  static bool _isMissingColumnError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42703') return true;
      final msg = error.message.toLowerCase();
      return msg.contains('does not exist') &&
          (msg.contains('column') ||
              msg.contains('user1_cleared_at') ||
              msg.contains('user2_cleared_at') ||
              msg.contains('read_at') ||
              msg.contains('deleted_at') ||
              msg.contains('deleted_for_everyone'));
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _selectConversations(String me) async {
    Future<List<dynamic>> run(String columns) {
      return _supabase
          .from('conversations')
          .select(columns)
          .or('user1_id.eq.$me,user2_id.eq.$me');
    }

    if (_convoClearColumns) {
      try {
        final rows = await run(
          'id, user1_id, user2_id, user1_cleared_at, user2_cleared_at',
        );
        return rows.cast<Map<String, dynamic>>();
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        _convoClearColumns = false;
      }
    }
    final rows = await run('id, user1_id, user2_id');
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _selectMessagesForConvos(
    List<String> convoIds,
  ) async {
    Future<List<dynamic>> run(String columns) {
      return _supabase
          .from('messages')
          .select(columns)
          .inFilter('conversation_id', convoIds)
          .order('created_at', ascending: false);
    }

    if (_messageReceiptColumns) {
      try {
        final rows = await run(
          'id, conversation_id, content, created_at, sender_id, '
          'read_at, deleted_at, deleted_for_everyone',
        );
        return rows.cast<Map<String, dynamic>>();
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        _messageReceiptColumns = false;
      }
    }
    final rows = await run(
      'id, conversation_id, content, created_at, sender_id',
    );
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<UserModel>> fetchUsers() async {
    final me = _currentUserId;
    final response = await _supabase.from('users').select();
    return (response as List<dynamic>)
        .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
        .where((u) => u.id != null && u.id != me)
        .toList();
  }

  Future<DashboardData> fetchDashboard() async {
    final me = _currentUserId;
    if (me == null) {
      return const DashboardData(activeChats: [], availableUsers: []);
    }

    final users = await fetchUsers();

    final conversations = await _selectConversations(me);

    final convoByOther = <String, String>{};
    final clearedByConvo = <String, DateTime?>{};
    for (final c in conversations) {
      final id = c['id'] as String?;
      if (id == null) continue;
      final u1 = c['user1_id'] as String?;
      final u2 = c['user2_id'] as String?;
      final other = u1 == me ? u2 : u1;
      if (other == null || other == me) continue;
      convoByOther[other] = id;
      final clearedRaw = (u1 == me)
          ? c['user1_cleared_at'] as String?
          : c['user2_cleared_at'] as String?;
      clearedByConvo[id] =
          clearedRaw == null ? null : DateTime.tryParse(clearedRaw);
    }

    final latestByConvo = <String, Map<String, dynamic>>{};
    final unreadByConvo = <String, int>{};

    if (convoByOther.isNotEmpty) {
      final convoIds = convoByOther.values.toList();
      final messages = await _selectMessagesForConvos(convoIds);

      for (final m in messages as List) {
        final map = m as Map<String, dynamic>;
        final cid = map['conversation_id'] as String?;
        if (cid == null) continue;

        final createdAtRaw = map['created_at'] as String?;
        final createdAt =
            createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw);
        if (createdAt == null) continue;

        final cleared = clearedByConvo[cid];
        if (cleared != null && !createdAt.toUtc().isAfter(cleared.toUtc())) {
          continue;
        }

        latestByConvo.putIfAbsent(cid, () => map);

        final senderId = map['sender_id'] as String?;
        if (senderId == me) continue;
        final readAtRaw = map['read_at'] as String?;
        final deletedForEveryone =
            map['deleted_for_everyone'] as bool? ?? false;
        if (readAtRaw == null && !deletedForEveryone) {
          unreadByConvo.update(cid, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    final activeChats = <ChatPreview>[];
    final availableUsers = <UserModel>[];

    for (final u in users) {
      final cid = u.id == null ? null : convoByOther[u.id!];
      if (cid == null) {
        availableUsers.add(u);
        continue;
      }
      final last = latestByConvo[cid];
      if (last == null) {
        availableUsers.add(u);
        continue;
      }
      final rawContent = last['content'] as String?;
      final createdAtRaw = last['created_at'] as String?;
      final senderId = last['sender_id'] as String?;
      final readAtRaw = last['read_at'] as String?;
      final deletedAt = last['deleted_at'] as String?;
      final deletedForEveryone =
          last['deleted_for_everyone'] as bool? ?? false;
      final isMine = senderId == me;
      final deleted = deletedAt != null || deletedForEveryone;

      MessageStatus status = MessageStatus.sent;
      if (isMine && readAtRaw != null) status = MessageStatus.read;

      activeChats.add(
        ChatPreview(
          otherUser: u,
          conversationId: cid,
          lastMessage: deleted
              ? null
              : (rawContent == null
                  ? null
                  : MessageCrypto.decryptText(rawContent, cid)),
          lastMessageAt: createdAtRaw == null
              ? null
              : DateTime.tryParse(createdAtRaw),
          lastMessageMine: isMine,
          lastMessageDeleted: deleted,
          lastMessageStatus: status,
          unreadCount: unreadByConvo[cid] ?? 0,
        ),
      );
    }

    activeChats.sort((a, b) {
      final at = a.lastMessageAt;
      final bt = b.lastMessageAt;
      if (at == null && bt == null) {
        return (a.otherUser.name ?? '').compareTo(b.otherUser.name ?? '');
      }
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

    availableUsers.sort(
      (a, b) => (a.name ?? '').toLowerCase().compareTo(
            (b.name ?? '').toLowerCase(),
          ),
    );

    final result = DashboardData(
      activeChats: activeChats,
      availableUsers: availableUsers,
    );
    // Persist to Hive so the next cold open can render instantly.
    LocalCache.saveDashboard(me, result.toJson());
    return result;
  }

  /// Synchronously read the most-recently-cached dashboard for the current
  /// user, or null if no cache exists.
  DashboardData? cachedDashboard() {
    final me = _currentUserId;
    if (me == null) return null;
    final raw = LocalCache.loadDashboard(me);
    if (raw == null) return null;
    try {
      return DashboardData.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Synchronously read the most-recently-cached message list for the given
  /// conversation, decrypted into the same shape the live stream produces.
  List<Map<String, dynamic>>? cachedMessages(String conversationId) {
    final raw = LocalCache.loadMessages(conversationId);
    if (raw == null) return null;
    return raw;
  }

  Future<String> createConversation(
    UserModel currentUser,
    UserModel otherUser,
  ) async {
    final existing = await _supabase
        .from('conversations')
        .select('id')
        .or(
          'and(user1_id.eq.${currentUser.id},user2_id.eq.${otherUser.id}),'
          'and(user1_id.eq.${otherUser.id},user2_id.eq.${currentUser.id})',
        );

    if ((existing as List).isNotEmpty) {
      return existing.first['id'] as String;
    }

    final created = await _supabase
        .from('conversations')
        .insert({
          'user1_id': currentUser.id,
          'user2_id': otherUser.id,
        })
        .select('id')
        .single();

    return created['id'] as String;
  }

  Future<String?> sendMessage(
    String conversationId,
    UserModel sender,
    String message,
  ) async {
    try {
      final ciphertext = MessageCrypto.encryptText(message, conversationId);
      final inserted = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': sender.id,
            'content': ciphertext,
          })
          .select('id')
          .single();
      return inserted['id'] as String?;
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    }
  }

  Future<DateTime?> _conversationClearedAt(String conversationId) async {
    final me = _currentUserId;
    if (me == null) return null;
    if (!_convoClearColumns) return null;
    try {
      final row = await _supabase
          .from('conversations')
          .select('user1_id, user1_cleared_at, user2_cleared_at')
          .eq('id', conversationId)
          .maybeSingle();
      if (row == null) return null;
      final isUser1 = row['user1_id'] == me;
      final raw = isUser1
          ? row['user1_cleared_at'] as String?
          : row['user2_cleared_at'] as String?;
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (e) {
      if (_isMissingColumnError(e)) {
        _convoClearColumns = false;
        return null;
      }
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> receiveMessages(String conversationId) {
    DateTime? cachedCleared;
    bool clearedFetched = false;
    Future<void> ensureCleared() async {
      if (clearedFetched) return;
      cachedCleared = await _conversationClearedAt(conversationId);
      clearedFetched = true;
    }

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .asyncMap((event) async {
          await ensureCleared();
          final cleared = cachedCleared;
          final mapped = event.where((msg) {
            if (cleared == null) return true;
            final createdAtRaw = msg['created_at'] as String?;
            final createdAt = createdAtRaw == null
                ? null
                : DateTime.tryParse(createdAtRaw);
            if (createdAt == null) return true;
            return createdAt.toUtc().isAfter(cleared.toUtc());
          }).map((msg) {
            final raw = (msg['content'] as String?) ?? '';
            final deletedForEveryone =
                msg['deleted_for_everyone'] as bool? ?? false;
            final deletedAt = msg['deleted_at'] as String?;
            return {
              'id': msg['id'],
              'senderId': msg['sender_id'],
              'content': deletedForEveryone || deletedAt != null
                  ? ''
                  : MessageCrypto.decryptText(raw, conversationId),
              'createdAt': msg['created_at'],
              'readAt': msg['read_at'],
              'deletedAt': msg['deleted_at'],
              'deletedForEveryone': deletedForEveryone,
            };
          }).toList();
          // Persist for instant cold-open render next time.
          LocalCache.saveMessages(conversationId, mapped);
          return mapped;
        });
  }

  /// Mark every unread message *from the other side* in this conversation as
  /// read by the current user. Idempotent.
  Future<void> markConversationRead(String conversationId) async {
    final me = _currentUserId;
    if (me == null) return;
    try {
      await _supabase
          .from('messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('conversation_id', conversationId)
          .neq('sender_id', me)
          .filter('read_at', 'is', null);
    } catch (_) {
      // best-effort; don't break the chat if the column is missing
    }
  }

  /// Soft-delete a message I sent — recipient sees a "message deleted" tombstone.
  Future<void> deleteMessageForEveryone(String messageId) async {
    final me = _currentUserId;
    if (me == null) return;
    if (!_messageReceiptColumns) {
      throw Exception(
        'Message deletion needs the database migration in tools/schema.sql.',
      );
    }
    try {
      await _supabase
          .from('messages')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'deleted_for_everyone': true,
            'content': '',
          })
          .eq('id', messageId)
          .eq('sender_id', me);
    } catch (e) {
      if (_isMissingColumnError(e)) _messageReceiptColumns = false;
      rethrow;
    }
  }

  /// Hard-delete (only available within a small grace window for own messages).
  Future<void> deleteMessageForMe(String messageId) async {
    final me = _currentUserId;
    if (me == null) return;
    if (!_messageReceiptColumns) {
      throw Exception(
        'Message deletion needs the database migration in tools/schema.sql.',
      );
    }
    try {
      await _supabase
          .from('messages')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'content': '',
          })
          .eq('id', messageId)
          .eq('sender_id', me);
    } catch (e) {
      if (_isMissingColumnError(e)) _messageReceiptColumns = false;
      rethrow;
    }
  }

  /// Clear the conversation for the current user only — messages older than now
  /// stop showing up for them. The other side keeps the full history.
  Future<void> clearConversationForMe(String conversationId) async {
    final me = _currentUserId;
    if (me == null) return;
    if (!_convoClearColumns) {
      throw Exception(
        'Delete chat needs the database migration in tools/schema.sql.',
      );
    }
    try {
      final row = await _supabase
          .from('conversations')
          .select('user1_id')
          .eq('id', conversationId)
          .maybeSingle();
      if (row == null) return;
      final isUser1 = row['user1_id'] == me;
      final field = isUser1 ? 'user1_cleared_at' : 'user2_cleared_at';
      await _supabase
          .from('conversations')
          .update({field: DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);
    } catch (e) {
      if (_isMissingColumnError(e)) _convoClearColumns = false;
      rethrow;
    }
  }

  Future<UserModel> getCurrentUser() async {
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) {
      throw Exception('No logged-in user');
    }

    final data = await _supabase
        .from('users')
        .select()
        .eq('id', supabaseUser.id)
        .maybeSingle();

    return UserModel(
      id: supabaseUser.id,
      name: data?['name'] as String? ?? '',
      email: supabaseUser.email ?? '',
      bio: data?['bio'] as String?,
      lastSeen: data?['last_seen'] == null
          ? null
          : DateTime.tryParse(data!['last_seen'] as String),
    );
  }
}
