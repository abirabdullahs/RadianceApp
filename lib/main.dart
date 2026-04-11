import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/i18n/app_localizations.dart';
import 'app/language_settings.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'app/theme_settings.dart';
import 'core/auth/profile_role_notifier.dart';
import 'core/services/fcm_service.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeSettings = await ThemeSettings.loadFromPrefs();
  final languageSettings = await LanguageSettings.loadFromPrefs();
  await initSupabase();
  if (supabaseClient.auth.currentSession != null) {
    await profileRoleNotifier.refresh();
  }
  supabaseClient.auth.onAuthStateChange.listen((_) {
    profileRoleNotifier.refresh();
    FcmService.syncTokenAfterAuth();
  });
  await FcmService.init();
  await FcmService.syncTokenAfterAuth();
  runApp(
    ProviderScope(
      overrides: [
        themeSettingsProvider.overrideWith(
          (ref) => ThemeSettingsNotifier(initial: themeSettings),
        ),
        languageSettingsProvider.overrideWith(
          (ref) => LanguageSettingsNotifier(initial: languageSettings),
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
    final lang = ref.watch(languageSettingsProvider);
    return MaterialApp.router(
      title: 'Radiance',
      theme: AppTheme.lightFor(ts.variant),
      darkTheme: AppTheme.darkFor(ts.variant),
      themeMode: ts.mode,
      locale: lang.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
