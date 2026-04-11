import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../app/language_settings.dart';
import '../../../app/widgets/theme_picker_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/student_drawer.dart';

/// Student settings: link to profile edit + change password.
class StudentSettingsScreen extends ConsumerStatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  ConsumerState<StudentSettingsScreen> createState() =>
      _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends ConsumerState<StudentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPw = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _current.dispose();
    _newPw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _newPw.text,
          );
      if (!mounted) return;
      _current.clear();
      _newPw.clear();
      _confirm.clear();
      ref.invalidate(currentUserProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('password_changed'),
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('failed')}: ${_messageForError(e)}',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageForError(Object e) {
    final l10n = AppLocalizations.of(context);
    final s = e.toString().toLowerCase();
    if (s.contains('invalid') && s.contains('password')) {
      return l10n.t('wrong_current_password');
    }
    if (s.contains('same')) {
      return l10n.t('new_password_not_same');
    }
    return '$e';
  }

  InputDecoration _dec(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.hindSiliguri(),
      suffixIcon: suffix,
      alignLabelWithHint: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final currentLocale = ref.watch(languageSettingsProvider).locale.languageCode;

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          l10n.t('settings'),
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: const [AppBarDrawerAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.person_outline, color: scheme.primary),
              title: Text(
                l10n.t('edit_profile'),
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.t('name_address_photo'),
                style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/student/profile/edit'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined, color: scheme.primary),
              title: Text(
                l10n.t('theme_and_colors'),
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.t('choose_theme_colors'),
                style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showThemePickerSheet(context, ref),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.language_outlined, color: scheme.primary),
              title: Text(
                l10n.t('language'),
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.t('choose_language'),
                style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLocale == 'en' ? l10n.t('english') : l10n.t('bangla'),
                    style: GoogleFonts.hindSiliguri(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () async {
                final selected = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) {
                    final selectedCode = ref
                        .read(languageSettingsProvider)
                        .locale
                        .languageCode;
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.translate),
                            title: Text(
                              l10n.t('bangla'),
                              style: GoogleFonts.hindSiliguri(),
                            ),
                            trailing: selectedCode == 'bn'
                                ? Icon(Icons.check, color: scheme.primary)
                                : null,
                            onTap: () => Navigator.of(ctx).pop('bn'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.translate),
                            title: Text(
                              l10n.t('english'),
                              style: GoogleFonts.hindSiliguri(),
                            ),
                            trailing: selectedCode == 'en'
                                ? Icon(Icons.check, color: scheme.primary)
                                : null,
                            onTap: () => Navigator.of(ctx).pop('en'),
                          ),
                        ],
                      ),
                    );
                  },
                );
                if (selected == null) return;
                await ref
                    .read(languageSettingsProvider.notifier)
                    .setLocale(Locale(selected));
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.t('change_password'),
            style: GoogleFonts.hindSiliguri(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _current,
                  enabled: !_submitting,
                  obscureText: _obscureCurrent,
                  decoration: _dec(
                    l10n.t('current_password'),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  style: GoogleFonts.nunito(),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l10n.t('current_password_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPw,
                  enabled: !_submitting,
                  obscureText: _obscureNew,
                  decoration: _dec(
                    l10n.t('new_password_min'),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  style: GoogleFonts.nunito(),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return l10n.t('min_6_chars');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  enabled: !_submitting,
                  obscureText: _obscureConfirm,
                  decoration: _dec(
                    l10n.t('new_password_again'),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  style: GoogleFonts.nunito(),
                  validator: (v) {
                    if (v != _newPw.text) return l10n.t('not_matching');
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _changePassword,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.t('update_password'),
                          style: GoogleFonts.hindSiliguri(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
