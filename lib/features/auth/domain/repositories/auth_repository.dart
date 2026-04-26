import '../entities/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> signUp(UserModel userModel);
  Future<UserModel?> signIn(String email, String password);
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  Future<UserModel?> updateProfile({required String name, required String bio});
}
