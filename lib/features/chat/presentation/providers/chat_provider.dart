import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/chat_service.dart';
import '../../data/services/presence_service.dart';
import '../../domain/entities/chat_preview.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// Synchronous read of the most-recent dashboard snapshot from disk. Lets the
/// UI render content on first frame, even before the live fetch completes.
final cachedDashboardProvider = Provider<DashboardData?>((ref) {
  return ref.watch(chatServiceProvider).cachedDashboard();
});

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final service = ref.watch(chatServiceProvider);
  return service.fetchDashboard();
});

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService();
  ref.onDispose(service.dispose);
  return service;
});

final presenceProvider = StreamProvider<PresenceSnapshot>((ref) async* {
  yield PresenceSnapshot.empty;
  try {
    final service = ref.watch(presenceServiceProvider);
    await service.connect();
    yield* service.snapshots;
  } catch (_) {
    // presence is best-effort; never break the dashboard
  }
});

/// Backward-compatible: still expose just the online set.
final onlineUsersProvider = Provider<Set<String>>((ref) {
  return ref.watch(presenceProvider).maybeWhen(
        data: (s) => s.onlineIds,
        orElse: () => const <String>{},
      );
});
