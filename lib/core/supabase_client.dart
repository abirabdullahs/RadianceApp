import 'package:supabase_flutter/supabase_flutter.dart';

/// Environment keys for `flutter run` / build:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
const String _kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String _kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Call after [WidgetsFlutterBinding.ensureInitialized] and before [runApp].
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: _kSupabaseUrl,
    anonKey: _kSupabaseAnonKey,
  );
}

/// Root Supabase client (Auth, PostgREST, Realtime, etc.).
SupabaseClient get supabaseClient => Supabase.instance.client;

/// Storage API (buckets, upload/download).
SupabaseStorageClient get supabaseStorage => supabaseClient.storage;
