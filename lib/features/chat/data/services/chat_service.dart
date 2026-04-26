import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/entities/user_model.dart';

class ChatService {
  ChatService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<UserModel>> fetchUsers() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final response = await _supabase.from('users').select();
    final data = response as List<dynamic>;

    return data
        .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
        .where((u) => u.id != currentUserId)
        .toList();
  }

  Future<String> createConversation(
    UserModel currentUser,
    UserModel otherUser,
  ) async {
    final existing = await _supabase
        .from('conversations')
        .select()
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
        .select()
        .single();

    return created['id'] as String;
  }

  Future<void> sendMessage(
    String conversationId,
    UserModel sender,
    String message,
  ) async {
    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': sender.id,
      'content': message,
    });
  }

  Stream<List<Map<String, dynamic>>> receiveMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((event) {
          return event.map((msg) {
            return {
              'id': msg['id'],
              'senderId': msg['sender_id'],
              'content': msg['content'] ?? '',
              'createdAt': msg['created_at'],
            };
          }).toList();
        });
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
    );
  }
}
