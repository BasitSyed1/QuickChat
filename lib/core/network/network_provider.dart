import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline, unknown }

class NetworkSnapshot {
  final NetworkStatus status;
  final List<ConnectivityResult> raw;
  const NetworkSnapshot(this.status, this.raw);

  bool get isOnline => status == NetworkStatus.online;
  bool get isOffline => status == NetworkStatus.offline;
}

NetworkStatus _statusFor(List<ConnectivityResult> results) {
  if (results.isEmpty) return NetworkStatus.unknown;
  final hasReal = results.any(
    (r) => r != ConnectivityResult.none,
  );
  return hasReal ? NetworkStatus.online : NetworkStatus.offline;
}

/// Live connectivity status. Emits initial state immediately, then every time
/// the OS reports a change. Always emits `unknown` first so widgets can render
/// without flashing an offline banner before we know.
final networkProvider = StreamProvider<NetworkSnapshot>((ref) async* {
  final conn = Connectivity();
  yield const NetworkSnapshot(NetworkStatus.unknown, []);
  try {
    final initial = await conn.checkConnectivity();
    yield NetworkSnapshot(_statusFor(initial), initial);
  } catch (_) {
    yield const NetworkSnapshot(NetworkStatus.unknown, []);
  }
  await for (final results in conn.onConnectivityChanged) {
    yield NetworkSnapshot(_statusFor(results), results);
  }
});

/// Convenience: bool that's true while we *know* we're offline. `unknown`
/// (still resolving) does not count, so the banner doesn't flicker.
final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(networkProvider).maybeWhen(
        data: (snap) => snap.isOffline,
        orElse: () => false,
      );
});
