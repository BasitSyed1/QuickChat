class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? deletedAt;
  final bool deletedForEveryone;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.deletedAt,
    this.deletedForEveryone = false,
  });

  bool get isDeleted => deletedAt != null || deletedForEveryone;
  bool get isRead => readAt != null;

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      readAt: _parseDate(map['read_at']),
      deletedAt: _parseDate(map['deleted_at']),
      deletedForEveryone: map['deleted_for_everyone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
        if (readAt != null) 'read_at': readAt!.toIso8601String(),
        if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
        'deleted_for_everyone': deletedForEveryone,
      };

  static DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
