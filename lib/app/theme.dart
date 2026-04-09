import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// User-selectable palette (see [AppTheme.lightFor] / [darkFor]).
enum AppThemeVariant {
  radiance,
  emerald,
  plum,
  sunset,
  slate,
}

extension AppThemeVariantLabels on AppThemeVariant {
  String get labelBn => switch (this) {
        AppThemeVariant.radiance => 'রেডিয়ান্স (নীল)',
        AppThemeVariant.emerald => 'সবুজ',
        AppThemeVariant.plum => 'বেগুনি',
        AppThemeVariant.sunset => 'সূর্যাস্ত (কমলা)',
        AppThemeVariant.slate => 'স্লেট (ধূসর)',
      };
}

/// Radiance design tokens and [ThemeData] for light and dark mode.
///
/// Default body and title text use [GoogleFonts.hindSiliguri]. Display,
/// headlines, [titleLarge], and labels use [GoogleFonts.nunito] for English
/// numerals and UI labels.
extension ThemePrimaryX on BuildContext {
  /// Current palette primary (respects [AppThemeVariant]).
  Color get themePrimary => Theme.of(this).colorScheme.primary;
}

abstract final class AppTheme {
  /// Default seed (Radiance). Prefer [ThemePrimaryX.themePrimary] or `colorScheme.primary` in UI.
  static const Color primary = Color(0xFF1A3C6E);
  static const Color accent = Color(0xFFF5A623);

  static const double cardRadius = 12;

  static const Color _lightSurface = Color(0xFFF8F9FA);
  static const Color _darkSurface = Color(0xFF0F1923);

  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      );

  static ThemeData lightFor(AppThemeVariant v) =>
      _buildTheme(_lightScheme(v), ThemeData(brightness: Brightness.light, useMaterial3: true));

  static ThemeData darkFor(AppThemeVariant v) =>
      _buildTheme(_darkScheme(v), ThemeData(brightness: Brightness.dark, useMaterial3: true));

  /// Back-compat: Radiance light.
  static ThemeData get lightTheme => lightFor(AppThemeVariant.radiance);

  /// Back-compat: Radiance dark.
  static ThemeData get darkTheme => darkFor(AppThemeVariant.radiance);

  static ColorScheme _lightScheme(AppThemeVariant v) {
    return switch (v) {
      AppThemeVariant.radiance => ColorScheme.light(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFD0E0F5),
          onPrimaryContainer: const Color(0xFF0D1F3D),
          secondary: accent,
          onSecondary: const Color(0xFF1A1204),
          secondaryContainer: const Color(0xFFFFE7C2),
          onSecondaryContainer: const Color(0xFF3D2A00),
          surface: _lightSurface,
          onSurface: const Color(0xFF1B1B1B),
          surfaceContainerHighest: const Color(0xFFE8EAED),
          error: const Color(0xFFE74C3C),
          onError: Colors.white,
        ),
      AppThemeVariant.emerald => ColorScheme.light(
          primary: const Color(0xFF0D5C4A),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFB2DFDB),
          onPrimaryContainer: const Color(0xFF002019),
          secondary: const Color(0xFF2E7D32),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFC8E6C9),
          onSecondaryContainer: const Color(0xFF1B3D1E),
          surface: const Color(0xFFF5FAF7),
          onSurface: const Color(0xFF1B1B1B),
          surfaceContainerHighest: const Color(0xFFE0EFEA),
          error: const Color(0xFFE74C3C),
          onError: Colors.white,
        ),
      AppThemeVariant.plum => ColorScheme.light(
          primary: const Color(0xFF5E35B1),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE1BEE7),
          onPrimaryContainer: const Color(0xFF210047),
          secondary: const Color(0xFF8E24AA),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFF3E5F5),
          onSecondaryContainer: const Color(0xFF4A0072),
          surface: const Color(0xFFF9F5FC),
          onSurface: const Color(0xFF1B1B1B),
          surfaceContainerHighest: const Color(0xFFECE4F5),
          error: const Color(0xFFE74C3C),
          onError: Colors.white,
        ),
      AppThemeVariant.sunset => ColorScheme.light(
          primary: const Color(0xFFC43E00),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFDCC4),
          onPrimaryContainer: const Color(0xFF3D0E00),
          secondary: const Color(0xFFE65100),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFFE0B2),
          onSecondaryContainer: const Color(0xFF4E2500),
          surface: const Color(0xFFFFFAF5),
          onSurface: const Color(0xFF1B1B1B),
          surfaceContainerHighest: const Color(0xFFF5E6DC),
          error: const Color(0xFFE74C3C),
          onError: Colors.white,
        ),
      AppThemeVariant.slate => ColorScheme.light(
          primary: const Color(0xFF37474F),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFCFD8DC),
          onPrimaryContainer: const Color(0xFF0D1619),
          secondary: const Color(0xFF546E7A),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFECEFF1),
          onSecondaryContainer: const Color(0xFF263238),
          surface: const Color(0xFFF7F9FA),
          onSurface: const Color(0xFF1B1B1B),
          surfaceContainerHighest: const Color(0xFFE2E8EB),
          error: const Color(0xFFE74C3C),
          onError: Colors.white,
        ),
    };
  }

  static ColorScheme _darkScheme(AppThemeVariant v) {
    return switch (v) {
      AppThemeVariant.radiance => ColorScheme.dark(
          primary: const Color(0xFF6B8FCC),
          onPrimary: const Color(0xFF0A1628),
          primaryContainer: const Color(0xFF284878),
          onPrimaryContainer: const Color(0xFFD8E6FA),
          secondary: accent,
          onSecondary: const Color(0xFF1A1204),
          secondaryContainer: const Color(0xFF6B4A00),
          onSecondaryContainer: const Color(0xFFFFE7C2),
          surface: _darkSurface,
          onSurface: const Color(0xFFE8EAED),
          surfaceContainerHighest: const Color(0xFF2A3440),
          error: const Color(0xFFFF8A7A),
          onError: const Color(0xFF410002),
        ),
      AppThemeVariant.emerald => ColorScheme.dark(
          primary: const Color(0xFF4DB6AC),
          onPrimary: const Color(0xFF002019),
          primaryContainer: const Color(0xFF004D40),
          onPrimaryContainer: const Color(0xFFB2DFDB),
          secondary: const Color(0xFF81C784),
          onSecondary: const Color(0xFF0D1F0E),
          secondaryContainer: const Color(0xFF1B5E20),
          onSecondaryContainer: const Color(0xFFE8F5E9),
          surface: const Color(0xFF0F1A17),
          onSurface: const Color(0xFFE8EAED),
          surfaceContainerHighest: const Color(0xFF263832),
          error: const Color(0xFFFF8A7A),
          onError: const Color(0xFF410002),
        ),
      AppThemeVariant.plum => ColorScheme.dark(
          primary: const Color(0xFFB39DDB),
          onPrimary: const Color(0xFF210047),
          primaryContainer: const Color(0xFF4527A0),
          onPrimaryContainer: const Color(0xFFE1BEE7),
          secondary: const Color(0xFFCE93D8),
          onSecondary: const Color(0xFF2D0A38),
          secondaryContainer: const Color(0xFF6A1B9A),
          onSecondaryContainer: const Color(0xFFF3E5F5),
          surface: const Color(0xFF141018),
          onSurface: const Color(0xFFE8EAED),
          surfaceContainerHighest: const Color(0xFF2D2438),
          error: const Color(0xFFFF8A7A),
          onError: const Color(0xFF410002),
        ),
      AppThemeVariant.sunset => ColorScheme.dark(
          primary: const Color(0xFFFFAB91),
          onPrimary: const Color(0xFF3D0E00),
          primaryContainer: const Color(0xFF8B2E00),
          onPrimaryContainer: const Color(0xFFFFDCC4),
          secondary: const Color(0xFFFFB74D),
          onSecondary: const Color(0xFF3E1F00),
          secondaryContainer: const Color(0xFFE65100),
          onSecondaryContainer: const Color(0xFFFFE0B2),
          surface: const Color(0xFF1A1410),
          onSurface: const Color(0xFFE8EAED),
          surfaceContainerHighest: const Color(0xFF3D3028),
          error: const Color(0xFFFF8A7A),
          onError: const Color(0xFF410002),
        ),
      AppThemeVariant.slate => ColorScheme.dark(
          primary: const Color(0xFF90A4AE),
          onPrimary: const Color(0xFF0D1619),
          primaryContainer: const Color(0xFF37474F),
          onPrimaryContainer: const Color(0xFFCFD8DC),
          secondary: const Color(0xFFB0BEC5),
          onSecondary: const Color(0xFF1C2529),
          secondaryContainer: const Color(0xFF455A64),
          onSecondaryContainer: const Color(0xFFECEFF1),
          surface: const Color(0xFF121618),
          onSurface: const Color(0xFFE8EAED),
          surfaceContainerHighest: const Color(0xFF2E383E),
          error: const Color(0xFFFF8A7A),
          onError: const Color(0xFF410002),
        ),
    };
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, ThemeData base) {
    final hind = GoogleFonts.hindSiliguriTextTheme(base.textTheme);
    final nunito = GoogleFonts.nunitoTextTheme(base.textTheme);
    final textTheme = hind.copyWith(
      displayLarge: nunito.displayLarge,
      displayMedium: nunito.displayMedium,
      displaySmall: nunito.displaySmall,
      headlineLarge: nunito.headlineLarge,
      headlineMedium: nunito.headlineMedium,
      headlineSmall: nunito.headlineSmall,
      titleLarge: nunito.titleLarge,
      labelLarge: nunito.labelLarge,
      labelMedium: nunito.labelMedium,
      labelSmall: nunito.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.nunitoTextTheme(base.primaryTextTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(shape: cardShape),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
    );
  }
}
