import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/ai_service.dart';
import '../../domain/entities/ai_message.dart';

class AiChatState {
  final List<AiMessage> messages;
  final bool sending;
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.sending = false,
    this.error,
  });

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? sending,
    String? error,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  static const _storageKey = 'ai_chat_history_v1';

  late final AiService _service;

  @override
  AiChatState build() {
    _service = AiService();
    _loadFromDisk();
    return const AiChatState();
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(AiMessage.fromJson)
          .toList();
      state = state.copyWith(messages: list);
    } catch (_) {/* ignore */}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(state.messages.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {/* best-effort */}
  }

  Future<void> send(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty || state.sending) return;

    final userMsg = AiMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    final history = List<AiMessage>.from(state.messages);
    state = state.copyWith(
      messages: [...history, userMsg],
      sending: true,
      clearError: true,
    );
    _persist();

    try {
      final reply = await _service.ask(prompt: trimmed, history: history);
      final aiMsg = AiMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}-ai',
        role: AiRole.assistant,
        content: reply,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        sending: false,
      );
      _persist();
    } catch (e) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      state = state.copyWith(sending: false, error: msg);
    }
  }

  Future<void> clear() async {
    state = const AiChatState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {/* ignore */}
  }

  void dismissError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final aiChatProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);
