class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String messageType;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'text',
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'message_type': messageType,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };
}
