import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_settings.dart';
import 'core/auth/profile_role_notifier.dart';
import 'core/services/fcm_service.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeSettings = await ThemeSettings.loadFromPrefs();
  await initSupabase();
  if (supabaseClient.auth.currentSession != null) {
    await profileRoleNotifier.refresh();
  }
  supabaseClient.auth.onAuthStateChange.listen((_) {
    profileRoleNotifier.refresh();
  });
  await FcmService.init();
  runApp(
    ProviderScope(
      overrides: [
        themeSettingsProvider.overrideWith(
          (ref) => ThemeSettingsNotifier(initial: themeSettings),
        ),
      ],
      child: const RadianceApp(),
    ),
  );
}

class RadianceApp extends ConsumerWidget {
  const RadianceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = ref.watch(themeSettingsProvider);
    return MaterialApp.router(
      title: 'Radiance',
      theme: AppTheme.lightFor(ts.variant),
      darkTheme: AppTheme.darkFor(ts.variant),
      themeMode: ts.mode,
      routerConfig: appRouter,
    );
  }
}
