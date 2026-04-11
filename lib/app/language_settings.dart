import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'k_app_locale';

class LanguageSettings {
  const LanguageSettings({required this.locale});

  final Locale locale;

  LanguageSettings copyWith({Locale? locale}) {
    return LanguageSettings(locale: locale ?? this.locale);
  }

  static Future<LanguageSettings> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey) ?? 'bn';
    return LanguageSettings(locale: _localeFromCode(code));
  }

  static Locale _localeFromCode(String code) {
    if (code == 'en') return const Locale('en');
    return const Locale('bn');
  }
}

final languageSettingsProvider =
    StateNotifierProvider<LanguageSettingsNotifier, LanguageSettings>((ref) {
  return LanguageSettingsNotifier();
});

class LanguageSettingsNotifier extends StateNotifier<LanguageSettings> {
  LanguageSettingsNotifier({LanguageSettings? initial})
      : super(initial ?? const LanguageSettings(locale: Locale('bn')));

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}
