import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../i18n/app_localizations.dart';
import '../theme.dart';
import '../theme_settings.dart';

/// Bottom sheet: রঙের থিম + লাইট/ডার্ক/সিস্টেম।
Future<void> showThemePickerSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Consumer(
            builder: (context, ref, _) {
              final ts = ref.watch(themeSettingsProvider);
              final scheme = Theme.of(context).colorScheme;
              final l10n = AppLocalizations.of(context);

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('choose_theme'),
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('change_color_mode'),
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('color_theme'),
                      style: GoogleFonts.hindSiliguri(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...AppThemeVariant.values.map(
                      (v) => ListTile(
                        title: Text(v.labelBn, style: GoogleFonts.hindSiliguri()),
                        trailing: ts.variant == v
                            ? Icon(Icons.check, color: scheme.primary)
                            : null,
                        onTap: () =>
                            ref.read(themeSettingsProvider.notifier).setVariant(v),
                      ),
                    ),
                    const Divider(),
                    Text(
                      l10n.t('display_mode'),
                      style: GoogleFonts.hindSiliguri(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(l10n.t('system_mode'), style: GoogleFonts.hindSiliguri()),
                      trailing: ts.mode == ThemeMode.system
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () =>
                          ref.read(themeSettingsProvider.notifier).setMode(ThemeMode.system),
                    ),
                    ListTile(
                      title: Text(l10n.t('light_mode'), style: GoogleFonts.hindSiliguri()),
                      trailing: ts.mode == ThemeMode.light
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () =>
                          ref.read(themeSettingsProvider.notifier).setMode(ThemeMode.light),
                    ),
                    ListTile(
                      title: Text(l10n.t('dark_mode'), style: GoogleFonts.hindSiliguri()),
                      trailing: ts.mode == ThemeMode.dark
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () =>
                          ref.read(themeSettingsProvider.notifier).setMode(ThemeMode.dark),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
