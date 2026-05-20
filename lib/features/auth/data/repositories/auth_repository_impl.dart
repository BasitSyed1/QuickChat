import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<T> _guardNetwork<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<UserModel?> signIn(String email, String password) {
    return _guardNetwork(() async {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Invalid email or password');
      }

      final data = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return UserModel(
        id: user.id,
        email: user.email,
        name: data?['name'] as String?,
        bio: data?['bio'] as String?,
      );
    });
  }

  @override
  Future<UserModel?> signUp(UserModel userModel) {
    return _guardNetwork(() async {
      final response = await _client.auth.signUp(
        email: userModel.email!,
        password: userModel.password!,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Sign up failed');
      }

      await _client.from('users').insert({
        'id': user.id,
        'name': userModel.name,
        'email': user.email,
      });

      return UserModel(
        id: user.id,
        email: user.email,
        name: userModel.name,
      );
    });
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) {
    return _guardNetwork(() => _client.auth.resetPasswordForEmail(email));
  }

  @override
  Future<UserModel?> getCurrentUser() {
    return _guardNetwork(() async {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final data = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return UserModel(
        id: user.id,
        email: user.email,
        name: data?['name'] as String?,
        bio: data?['bio'] as String?,
      );
    });
  }

  @override
  Future<UserModel?> updateProfile({
    required String name,
    required String bio,
  }) {
    return _guardNetwork(() async {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('No logged-in user');

      final response = await _client
          .from('users')
          .update({'name': name, 'bio': bio})
          .eq('id', user.id)
          .select()
          .single();

      return UserModel(
        id: user.id,
        email: user.email,
        name: response['name'] as String?,
        bio: response['bio'] as String?,
      );
    });
  }
}
