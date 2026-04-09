import 'package:flutter/foundation.dart';

import '../../features/auth/repositories/auth_repository.dart';
import '../supabase_client.dart';
import 'auth_metadata.dart';

/// Caches [users.role] from Postgres so routing matches the dashboard (JWT
/// [app_metadata.role] is often unset when admins set role only in [users]).
final ProfileRoleNotifier profileRoleNotifier = ProfileRoleNotifier();

class ProfileRoleNotifier extends ChangeNotifier {
  String? _cachedRole;

  /// `'admin'`, `'student'`, or `null` if logged out / unknown.
  String? get cachedRole => _cachedRole;

  Future<void> refresh() async {
    final session = supabaseClient.auth.currentSession;
    if (session == null) {
      if (_cachedRole != null) {
        _cachedRole = null;
        notifyListeners();
      }
      return;
    }
    try {
      final u = await AuthRepository().getCurrentUser();
      final next = u?.role.name;
      if (_cachedRole != next) {
        _cachedRole = next;
        notifyListeners();
      }
    } catch (_) {
      if (_cachedRole != null) {
        _cachedRole = null;
        notifyListeners();
      }
    }
  }
}

/// [users.role] from cache first (set in dashboard), then JWT metadata.
String? effectiveRoleFromSession() {
  final session = supabaseClient.auth.currentSession;
  if (session == null) return null;
  final fromDb = profileRoleNotifier.cachedRole;
  if (fromDb != null) return fromDb;
  return roleFromSupabaseMetadata(session.user);
}
