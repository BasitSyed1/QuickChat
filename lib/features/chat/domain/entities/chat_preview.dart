import '../../../auth/domain/entities/user_model.dart';

enum MessageStatus { sending, sent, read }

class ChatPreview {
  final UserModel otherUser;
  final String? conversationId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final bool lastMessageMine;
  final bool lastMessageDeleted;
  final MessageStatus lastMessageStatus;
  final int unreadCount;

  const ChatPreview({
    required this.otherUser,
    this.conversationId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageMine = false,
    this.lastMessageDeleted = false,
    this.lastMessageStatus = MessageStatus.sent,
    this.unreadCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'user': otherUser.toJson(),
        'cid': conversationId,
        'lastMsg': lastMessage,
        'lastAt': lastMessageAt?.toUtc().toIso8601String(),
        'mine': lastMessageMine,
        'deleted': lastMessageDeleted,
        'status': lastMessageStatus.name,
        'unread': unreadCount,
      };

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    return ChatPreview(
      otherUser: UserModel.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? {}),
      ),
      conversationId: json['cid'] as String?,
      lastMessage: json['lastMsg'] as String?,
      lastMessageAt: json['lastAt'] is String
          ? DateTime.tryParse(json['lastAt'] as String)
          : null,
      lastMessageMine: json['mine'] as bool? ?? false,
      lastMessageDeleted: json['deleted'] as bool? ?? false,
      lastMessageStatus: MessageStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      unreadCount: json['unread'] as int? ?? 0,
    );
  }
}

class DashboardData {
  final List<ChatPreview> activeChats;
  final List<UserModel> availableUsers;

  const DashboardData({
    required this.activeChats,
    required this.availableUsers,
  });

  bool get isEmpty => activeChats.isEmpty && availableUsers.isEmpty;

  Map<String, dynamic> toJson() => {
        'chats': activeChats.map((c) => c.toJson()).toList(),
        'users': availableUsers.map((u) => u.toJson()).toList(),
      };

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final chats = (json['chats'] as List? ?? const [])
        .map((c) => ChatPreview.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
    final users = (json['users'] as List? ?? const [])
        .map((u) => UserModel.fromJson(Map<String, dynamic>.from(u as Map)))
        .toList();
    return DashboardData(activeChats: chats, availableUsers: users);
  }
}
