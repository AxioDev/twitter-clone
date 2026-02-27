import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/exceptions/app_exception.dart';
import '../../../core/utils/supabase_client.dart';
import '../models/app_user.dart';

class AuthRepository {
  final sb.SupabaseClient _client;

  AuthRepository([sb.SupabaseClient? client]) : _client = client ?? supabase;

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final userId = response.user!.id;

      final userData = await _client.from('users').insert({
        'id': userId,
        'username': username,
        'display_name': displayName,
      }).select().single();

      return AppUser.fromJson(userData);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userData = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .single();

      return AppUser.fromJson(userData);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw DatabaseException(e.toString());
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<sb.AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<AppUser?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', session.user.id)
          .single();
      return AppUser.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId => _client.auth.currentUser?.id;
}
