import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router.dart';
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

/// Phone OTP actions: loading and errors exposed as [AsyncValue].
@riverpod
class SignIn extends _$SignIn {
  @override
  FutureOr<void> build() {}

  /// Sends SMS OTP via Supabase Auth.
  Future<void> sendOTP(String phone) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithPhone(phone),
    );
  }

  /// Verifies OTP, refreshes profile, then navigates by [UserModel.role].
  Future<void> verifyOTP(String phone, String otp) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyOTP(phone, otp);
      ref.invalidate(currentUserProvider);
      final user = await repo.getCurrentUser();
      if (user == null) {
        throw StateError('Missing user profile after sign-in');
      }
      final path =
          user.role == UserRole.admin ? '/admin' : '/student';
      await FcmService.syncTokenAfterAuth();
      appRouter.go(path);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(currentUserProvider);
      appRouter.go('/home');
    });
  }
}
