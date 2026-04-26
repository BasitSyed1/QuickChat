import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<UserModel?> build() => _repo.getCurrentUser();

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.signIn(email, password));
  }

  Future<void> signUp(UserModel userModel) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.signUp(userModel));
  }

  Future<void> updateCurrentUser(String name, String bio) async {
    if (state.value == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.updateProfile(name: name, bio: bio),
    );
  }

  Future<void> signOut() async {
    state = await AsyncValue.guard(() async {
      await _repo.signOut();
      return null;
    });
  }
}
