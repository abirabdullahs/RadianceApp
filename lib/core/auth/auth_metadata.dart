import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads app role from Supabase Auth JWT metadata.
///
/// Prefer `app_metadata.role` (set by service role / triggers); falls back to
/// `user_metadata.role` if present.
String? roleFromSupabaseMetadata(User? user) {
  if (user == null) return null;
  final fromApp = user.appMetadata['role'];
  if (fromApp is String && fromApp.isNotEmpty) return fromApp;
  final fromUser = user.userMetadata?['role'];
  if (fromUser is String && fromUser.isNotEmpty) return fromUser;
  return null;
}
