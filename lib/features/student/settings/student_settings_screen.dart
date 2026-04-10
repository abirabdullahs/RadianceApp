import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
            'পাসওয়ার্ড পরিবর্তন হয়েছে',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ব্যর্থ: ${_messageForError(e)}',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageForError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid') && s.contains('password')) {
      return 'বর্তমান পাসওয়ার্ড ভুল';
    }
    if (s.contains('same')) {
      return 'নতুন পাসওয়ার্ড আগের মতো হতে পারবে না';
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          'সেটিংস',
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
                'প্রোফাইল সম্পাদনা',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'নাম, ঠিকানা, ছবি',
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
                'থিম ও রঙ',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'নীল, সবুজ, বেগুনি ইত্যাদি থেকে বাছাই করুন',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showThemePickerSheet(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'পাসওয়ার্ড পরিবর্তন',
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
                    'বর্তমান পাসওয়ার্ড',
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
                    if (v == null || v.isEmpty) return 'বর্তমান পাসওয়ার্ড দিন';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPw,
                  enabled: !_submitting,
                  obscureText: _obscureNew,
                  decoration: _dec(
                    'নতুন পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)',
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
                      return 'কমপক্ষে ৬ অক্ষর';
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
                    'নতুন পাসওয়ার্ড আবার',
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
                    if (v != _newPw.text) return 'মিলছে না';
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
                          'পাসওয়ার্ড আপডেট করুন',
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
