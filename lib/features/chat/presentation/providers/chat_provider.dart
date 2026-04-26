import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/user_model.dart';
import '../../data/services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final usersProvider = FutureProvider<List<UserModel>>((ref) async {
  final service = ref.watch(chatServiceProvider);
  return service.fetchUsers();
});
