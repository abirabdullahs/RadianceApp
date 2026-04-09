import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../app/theme.dart';
import '../../../app/widgets/theme_picker_sheet.dart';
import '../../../core/supabase_client.dart';
import '../providers/auth_provider.dart';

/// Email + password login (Supabase). Phone OTP disabled for testing.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignInStateChanged(AsyncValue<void>? previous, AsyncValue<void> next) {
    next.whenOrNull(
      error: (error, _) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _messageForError(error),
              style: GoogleFonts.hindSiliguri(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  String _messageForError(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is StateError) {
      final m = error.message;
      if (m.contains('Missing user profile')) {
        return 'প্রোফাইল পাওয়া যায়নি। Supabase → public.users এ এই ইউজারের রো আছে কিনা ও role সেট আছে কিনা দেখুন।';
      }
    }
    final s = error.toString();
    if (s.contains('UnauthorizedUserException')) {
      return 'এই অ্যাকাউন্টটি নিবন্ধিত নয়। public.users এ রো যোগ করুন বা কোচিং সেন্টারে যোগাযোগ করুন।';
    }
    if (s.contains('42P17') || s.contains('infinite recursion')) {
      return 'RLS (users): ১) 20260409170000 চালান ২) 20260409180000 চালান ৩) লগআউট→লগইন। public.users.role JWT তে সিঙ্ক হবে।';
    }
    if (s.contains('PostgrestException')) {
      final short = RegExp(r'message: ([^,]+)').firstMatch(s)?.group(1)?.trim();
      if (short != null && short.length < 180) {
        return 'সার্ভার: $short';
      }
    }
    return 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';
  }

  Future<void> _submit() async {
    final primary = Theme.of(context).colorScheme.primary;
    final id = _identifierController.text.trim();
    final password = _passwordController.text;
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'মোবাইল (শিক্ষার্থী) অথবা ইমেইল (অ্যাডমিন) দিন।',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (id.contains('@')) {
      final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(id);
      if (!emailOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'সঠিক ইমেইল দিন।',
              style: GoogleFonts.hindSiliguri(color: Colors.white),
            ),
            backgroundColor: primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      final d = id.replaceAll(RegExp(r'\D'), '');
      if (d.length != 11 || !d.startsWith('01')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'শিক্ষার্থী: ১১ সংখ্যার মোবাইল (০১...) দিন।',
              style: GoogleFonts.hindSiliguri(color: Colors.white),
            ),
            backgroundColor: primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'পাসওয়ার্ড দিন।',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref.read(signInProvider.notifier).signIn(id, password);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signInProvider, _onSignInStateChanged);

    final scheme = Theme.of(context).colorScheme;
    final loading = ref.watch(signInProvider).isLoading;
    final hasSession = supabaseClient.auth.currentSession != null;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'থিম',
                onPressed: loading ? null : () => showThemePickerSheet(context, ref),
                icon: const Icon(Icons.palette_outlined),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  _logoBlock(scheme),
                  const SizedBox(height: 28),
                  Text(
                    'লগইন',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'শিক্ষার্থী: মোবাইল + পাসওয়ার্ড (নম্বরের শেষ ৯ সংখ্যা)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.text,
                    autocorrect: false,
                    style: GoogleFonts.nunito(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'মোবাইল বা ইমেইল',
                      labelStyle: GoogleFonts.hindSiliguri(),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.nunito(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'পাসওয়ার্ড',
                      labelStyle: GoogleFonts.hindSiliguri(),
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                    ),
                    child: Text(
                      'লগইন',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: loading ? null : () => context.go('/home'),
                    child: Text(
                      'পাবলিক হোমে ফিরুন',
                      style: GoogleFonts.hindSiliguri(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasSession) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          loading ? null : () => ref.read(signInProvider.notifier).signOut(),
                      child: Text(
                        'লগআউট (আটকে থাকা সেশন সরান)',
                        style: GoogleFonts.hindSiliguri(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (loading)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logoBlock(ColorScheme scheme) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 48,
          color: scheme.primary,
        ),
      ),
    );
  }
}
