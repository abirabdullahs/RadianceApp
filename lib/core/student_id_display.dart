import '../shared/models/user_model.dart';
import 'constants.dart';

/// True if [s] looks like a Postgres/UUID auth id (not a human student id).
bool looksLikeUuid(String s) {
  final t = s.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(t);
}

/// Canonical id: `RCC` + last 9 digits of [raw] (digits only). Returns null if fewer than 9 digits.
String? canonicalRccStudentIdFromInput(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length < 9) return null;
  return '$kStudentIdPrefix${d.substring(d.length - 9)}';
}

/// Prefer DB [UserModel.student_id] when set and not UUID-shaped; else RCC + last 9 of phone.
String displayStudentIdForUser(UserModel user) {
  final sid = user.studentId?.trim();
  if (sid != null && sid.isNotEmpty && !looksLikeUuid(sid)) {
    return sid;
  }
  final fromPhone = canonicalRccStudentIdFromInput(user.phone);
  return fromPhone ?? sid ?? '—';
}
