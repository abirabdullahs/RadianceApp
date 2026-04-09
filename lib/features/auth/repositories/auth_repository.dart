import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/errors/unauthorized_user_exception.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/user_model.dart';

/// Supabase Auth (phone SMS OTP) + `users` table profile.
class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Sends a one-time code via SMS (configure SMS provider in Supabase Auth).
  Future<void> signInWithPhone(String phone) async {
    final e164 = _toE164Bd(phone);
    await _client.auth.signInWithOtp(phone: e164);
  }

  /// Verifies the SMS OTP, establishes a session, and loads the profile row.
  ///
  /// Throws [UnauthorizedUserException] if auth succeeds but `users` has no row
  /// for [User.id] (session is cleared before throwing).
  Future<Session> verifyOTP(String phone, String otp) async {
    final e164 = _toE164Bd(phone);
    final response = await _client.auth.verifyOTP(
      phone: e164,
      token: otp.trim(),
      type: OtpType.sms,
    );
    final session = response.session;
    if (session == null) {
      throw StateError('verifyOTP succeeded but returned no session');
    }
    await _requireUserRowOrThrow();
    return session;
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

  /// Upserts a `users` row by primary key (`id`).
  Future<void> saveProfile(UserModel user) async {
    final payload = Map<String, dynamic>.from(user.toJson())
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from(kTableUsers).upsert(
          payload,
          onConflict: 'id',
        );
  }

  Future<void> _requireUserRowOrThrow() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated after verifyOTP');
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

/// Normalizes common Bangladesh inputs to E.164 (`+8801XXXXXXXXX`).
String _toE164Bd(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[\s-]'), '');
  if (s.isEmpty) {
    throw const FormatException('Phone number is empty');
  }
  if (s.startsWith('+')) {
    return s;
  }
  if (s.startsWith('00')) {
    s = s.substring(2);
  }
  if (s.startsWith('0')) {
    s = '880${s.substring(1)}';
  } else if (!s.startsWith('880')) {
    if (s.length == 10) {
      s = '880$s';
    } else {
      throw FormatException('Unsupported phone format: $raw');
    }
  }
  return '+$s';
}
