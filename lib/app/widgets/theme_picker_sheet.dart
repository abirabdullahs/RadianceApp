import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'থিম বাছাই করুন',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'রঙের সেট ও লাইট/ডার্ক মোড এখান থেকে বদলান।',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'রঙের থিম',
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
                      'ডিসপ্লে মোড',
                      style: GoogleFonts.hindSiliguri(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text('সিস্টেম (ডিভাইস অনুযায়ী)', style: GoogleFonts.hindSiliguri()),
                      trailing: ts.mode == ThemeMode.system
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () =>
                          ref.read(themeSettingsProvider.notifier).setMode(ThemeMode.system),
                    ),
                    ListTile(
                      title: Text('লাইট', style: GoogleFonts.hindSiliguri()),
                      trailing: ts.mode == ThemeMode.light
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () =>
                          ref.read(themeSettingsProvider.notifier).setMode(ThemeMode.light),
                    ),
                    ListTile(
                      title: Text('ডার্ক', style: GoogleFonts.hindSiliguri()),
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
