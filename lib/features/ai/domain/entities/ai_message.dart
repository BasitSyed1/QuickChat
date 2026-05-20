enum AiRole { user, assistant }

class AiMessage {
  final String id;
  final AiRole role;
  final String content;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as String,
      role: AiRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => AiRole.user,
      ),
      content: json['content'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
