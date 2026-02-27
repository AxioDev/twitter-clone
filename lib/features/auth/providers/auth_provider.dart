import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository();

@riverpod
Stream<AuthState> authState(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

@riverpod
Future<AppUser?> currentUser(Ref ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).getCurrentUser();
}

@riverpod
String? currentUserId(Ref ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUserId;
}
