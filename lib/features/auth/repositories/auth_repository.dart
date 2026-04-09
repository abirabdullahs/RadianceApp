import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors/unauthorized_user_exception.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/user_model.dart';

/// Supabase Auth (email + password) + `users` table profile.
class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Email + password. Enable **Email** provider in Supabase; turn off email
  /// confirmation while testing if you want instant sign-in.
  Future<void> signInWithEmailPassword(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw StateError('Sign-in returned no session');
    }
    await _requireUserRowOrThrow();
  }

  /// Student: 11-digit BD mobile + password (last 9 digits of that number).
  /// Auth email is [studentAuthEmailFromPhone].
  Future<void> signInWithPhonePassword(String phone, String password) async {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11 || !digits.startsWith('01')) {
      throw FormatException('১১ সংখ্যার মোবাইল (০১...) দিন');
    }
    final email = studentAuthEmailFromPhone(digits);
    await signInWithEmailPassword(email, password);
  }

  /// Profile for the signed-in auth user, or `null` if not signed in or no row.
  Future<UserModel?> getCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from(kTableUsers)
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return UserModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Re-authenticates with [currentPassword] then sets a new password (session stays valid).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('লগইন নেই');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('অ্যাকাউন্টে ইমেইল নেই');
    }
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    final res = await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
    if (res.user == null) {
      throw StateError('পাসওয়ার্ড আপডেট ব্যর্থ');
    }
  }

  /// Upserts a `users` row by primary key (`id`).
  Future<void> saveProfile(UserModel user) async {
    final payload = Map<String, dynamic>.from(user.toJson())
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from(kTableUsers).upsert(
          payload,
          onConflict: 'id',
        );
  }

  /// Throws [UnauthorizedUserException] if auth succeeds but `users` has no row.
  Future<void> _requireUserRowOrThrow() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated after sign-in');
    }
    final row = await _client
        .from(kTableUsers)
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row != null) return;
    await _client.auth.signOut();
    throw const UnauthorizedUserException();
  }
}
