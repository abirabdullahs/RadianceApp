import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Persisted palette + light/dark/system.
class ThemeSettings {
  const ThemeSettings({
    this.variant = AppThemeVariant.radiance,
    this.mode = ThemeMode.system,
  });

  final AppThemeVariant variant;
  final ThemeMode mode;

  ThemeSettings copyWith({
    AppThemeVariant? variant,
    ThemeMode? mode,
  }) {
    return ThemeSettings(
      variant: variant ?? this.variant,
      mode: mode ?? this.mode,
    );
  }

  static Future<ThemeSettings> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt(_kVariantKey) ?? 0)
        .clamp(0, AppThemeVariant.values.length - 1);
    final m = (prefs.getInt(_kModeKey) ?? 0).clamp(0, ThemeMode.values.length - 1);
    return ThemeSettings(
      variant: AppThemeVariant.values[v],
      mode: ThemeMode.values[m],
    );
  }
}

const _kVariantKey = 'k_theme_variant';
const _kModeKey = 'k_theme_mode';

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>((ref) {
  return ThemeSettingsNotifier();
});

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  ThemeSettingsNotifier({ThemeSettings? initial})
      : super(initial ?? const ThemeSettings());

  Future<void> setVariant(AppThemeVariant v) async {
    state = state.copyWith(variant: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVariantKey, v.index);
  }

  Future<void> setMode(ThemeMode m) async {
    state = state.copyWith(mode: m);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kModeKey, m.index);
  }
}
