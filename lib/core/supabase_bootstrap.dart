/// Fallback Supabase credentials when you run **without** `--dart-define`.
///
/// **Option A (recommended for device / Play builds):** Paste your project values
/// from Supabase Dashboard → **Settings → API** (Project URL + `anon` public key).
/// The anon key is safe to ship in client apps — never put `service_role` here.
///
/// **Option B:** Keep these empty and always pass at build time:
/// `flutter run --dart-define=SUPABASE_URL=https://awvmevatqceayldichsh.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3dm1ldmF0cWNlYXlsZGljaHNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NjEzODIsImV4cCI6MjA5MTIzNzM4Mn0.D3sXd_4-3dqehc_4o4wUHWOJdUAqwQxNIP7Ry3hEnVs`
/// `flutter build apk --dart-define=SUPABASE_URL=https://awvmevatqceayldichsh.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3dm1ldmF0cWNlYXlsZGljaHNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NjEzODIsImV4cCI6MjA5MTIzNzM4Mn0.D3sXd_4-3dqehc_4o4wUHWOJdUAqwQxNIP7Ry3hEnVs`
///
/// Session persistence (stay logged in after OTP once) is handled by
/// `supabase_flutter` automatically once URL/key are valid.
/// dart-define=SUPABASE_URL=https://awvmevatqceayldichsh.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3dm1ldmF0cWNlYXlsZGljaHNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NjEzODIsImV4cCI6MjA5MTIzNzM4Mn0.D3sXd_4-3dqehc_4o4wUHWOJdUAqwQxNIP7Ry3hEnVs
const String kSupabaseUrlFallback = 'https://awvmevatqceayldichsh.supabase.co';
const String kSupabaseAnonKeyFallback =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3dm1ldmF0cWNlYXlsZGljaHNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NjEzODIsImV4cCI6MjA5MTIzNzM4Mn0.D3sXd_4-3dqehc_4o4wUHWOJdUAqwQxNIP7Ry3hEnVs';
