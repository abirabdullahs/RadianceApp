import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Radiance design tokens and [ThemeData] for light and dark mode.
///
/// Default body and title text use [GoogleFonts.hindSiliguri]. Display,
/// headlines, [titleLarge], and labels use [GoogleFonts.nunito] for English
/// numerals and UI labels.
abstract final class AppTheme {
  static const Color primary = Color(0xFF1A3C6E);
  static const Color accent = Color(0xFFF5A623);

  static const double cardRadius = 12;

  static const Color _lightSurface = Color(0xFFF8F9FA);
  static const Color _darkSurface = Color(0xFF0F1923);

  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      );

  static ThemeData get lightTheme {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
    );
    final colorScheme = ColorScheme.light(
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
    );

    return _buildTheme(colorScheme, base);
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
    );
    final colorScheme = ColorScheme.dark(
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
    );

    return _buildTheme(colorScheme, base);
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
