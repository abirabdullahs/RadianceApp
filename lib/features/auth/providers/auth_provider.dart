import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
import '../../../core/auth/profile_role_notifier.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/user_model.dart';
import '../repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// Supabase auth state stream ([AuthState]: session updates, sign-in, sign-out).
@Riverpod(keepAlive: true)
Stream<AuthState> authState(AuthStateRef ref) {
  return supabaseClient.auth.onAuthStateChange;
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}

/// Profile row for the signed-in user; recomputes when [authStateProvider] emits.
@riverpod
Future<UserModel?> currentUser(CurrentUserRef ref) async {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).getCurrentUser();
}

/// Sign-in / sign-out; loading and errors exposed as [AsyncValue].
@riverpod
class SignIn extends _$SignIn {
  @override
  FutureOr<void> build() {}

  /// মোবাইল + পাসওয়ার্ড (শিক্ষার্থী) অথবা ইমেইল + পাসওয়ার্ড (অ্যাডমিন).
  Future<void> signIn(String identifier, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      final id = identifier.trim();
      if (id.contains('@')) {
        await repo.signInWithEmailPassword(id, password);
      } else {
        await repo.signInWithPhonePassword(id, password);
      }
      ref.invalidate(currentUserProvider);
      await profileRoleNotifier.refresh();
      final user = await repo.getCurrentUser();
      if (user == null) {
        throw StateError('Missing user profile after sign-in');
      }
      final path = switch (user.role) {
        UserRole.admin => '/admin',
        UserRole.teacher => '/teacher',
        UserRole.student => '/student',
      };
      await FcmService.syncTokenAfterAuth();
      appRouter.go(path);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(currentUserProvider);
      await profileRoleNotifier.refresh();
      appRouter.go('/home');
    });
  }
}
