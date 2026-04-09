import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

/// Environment keys for `flutter run` / build:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
const String _kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Call after [WidgetsFlutterBinding.ensureInitialized] and before [runApp].
///
/// Auth session is persisted on device by [supabase_flutter] (secure storage) so
/// users who complete phone OTP once stay signed in until they sign out or clear app data.
Future<void> initSupabase() async {
  final url =
      _kSupabaseUrl.isNotEmpty ? _kSupabaseUrl : kSupabaseUrlFallback;
  final key = _kSupabaseAnonKey.isNotEmpty
      ? _kSupabaseAnonKey
      : kSupabaseAnonKeyFallback;

  if (url.isEmpty || key.isEmpty) {
    throw StateError(
      'Supabase URL/key missing. Either fill lib/core/supabase_bootstrap.dart '
      '(kSupabaseUrlFallback, kSupabaseAnonKeyFallback) or build with '
      '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  if (kDebugMode) {
    debugPrint('Supabase: using host ${Uri.parse(url).host}');
  }

  await Supabase.initialize(
    url: url,
    anonKey: key,
  );
}

/// Same anon key passed to [initSupabase]. Use for Edge Function `apikey` when
/// overriding headers so the gateway matches the signed-in project.
String get resolvedSupabaseAnonKey {
  return _kSupabaseAnonKey.isNotEmpty ? _kSupabaseAnonKey : kSupabaseAnonKeyFallback;
}

/// Root Supabase client (Auth, PostgREST, Realtime, etc.).
SupabaseClient get supabaseClient => Supabase.instance.client;

/// Storage API (buckets, upload/download).
SupabaseStorageClient get supabaseStorage => supabaseClient.storage;
