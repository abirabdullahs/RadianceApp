import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../providers/auth_provider.dart';

/// Phone OTP login: step 1 send SMS, step 2 verify 6-digit code.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendSeconds = 0;

  /// 1 = phone, 2 = OTP
  int _step = 1;
  String _phoneForOtp = '';
  bool _otpSubmitting = false;

  static const int _otpLength = 6;

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

    if (previous?.isLoading == true &&
        next.hasValue &&
        _step == 1 &&
        mounted) {
      setState(() {
        _step = 2;
        _phoneForOtp = _phoneController.text.trim();
        _clearOtpFields();
        _startResendCountdown();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _otpFocus[0].requestFocus();
        });
      });
    }
  }

  String _messageForError(Object error) {
    final s = error.toString();
    if (s.contains('FormatException')) {
      return 'ফোন নম্বরটি সঠিক নয়।';
    }
    if (s.contains('UnauthorizedUserException')) {
      return 'এই নম্বরটি নিবন্ধিত নয়। কোচিং সেন্টারে যোগাযোগ করুন।';
    }
    return 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
    _otpSubmitting = false;
  }

  Future<void> _sendOtp() async {
    final raw = _phoneController.text.trim();
    final validBd = raw.length == 11 && raw.startsWith('01');
    if (!validBd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'সঠিক ১১ সংখ্যার মোবাইল নম্বর দিন (০১XXXXXXXXX)।',
            style: GoogleFonts.hindSiliguri(color: Colors.white),
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref.read(signInProvider.notifier).sendOTP(raw);
  }

  Future<void> _verifyOtp() async {
    if (_otpSubmitting) return;
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != _otpLength) return;

    _otpSubmitting = true;
    await ref.read(signInProvider.notifier).verifyOTP(_phoneForOtp, otp);
    if (mounted) _otpSubmitting = false;
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    await ref.read(signInProvider.notifier).sendOTP(_phoneForOtp);
    if (mounted) {
      _clearOtpFields();
      _startResendCountdown();
      _otpFocus[0].requestFocus();
    }
  }

  String _maskedPhoneLine() {
    final p = _phoneForOtp.replaceAll(RegExp(r'\s'), '');
    if (p.length < 6) return p;
    final start = p.substring(0, p.length >= 5 ? 5 : p.length);
    final end = p.length > 2 ? p.substring(p.length - 2) : '';
    return 'আপনার $start••••$end নম্বরে OTP পাঠানো হয়েছে';
  }

  void _onOtpChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _distributePastedOtp(digits);
      return;
    }
    if (value.isNotEmpty && index < _otpLength - 1) {
      _otpFocus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }

    if (_otpFilled) {
      _verifyOtp();
    }
  }

  void _distributePastedOtp(String digits) {
    final chars = digits.split('');
    for (var i = 0; i < _otpLength && i < chars.length; i++) {
      _otpControllers[i].text = chars[i];
    }
    if (chars.length >= _otpLength) {
      _otpFocus[_otpLength - 1].requestFocus();
      _verifyOtp();
    } else if (chars.isNotEmpty) {
      _otpFocus[chars.length.clamp(0, _otpLength - 1)].requestFocus();
    }
  }

  bool get _otpFilled =>
      _otpControllers.every((c) => c.text.isNotEmpty) &&
      _otpControllers.map((c) => c.text).join().length == _otpLength;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signInProvider, _onSignInStateChanged);

    final scheme = Theme.of(context).colorScheme;
    final signIn = ref.watch(signInProvider);
    final loading = signIn.isLoading;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _step == 1
                  ? _buildPhoneStep(scheme)
                  : _buildOtpStep(scheme, loading),
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

  Widget _buildPhoneStep(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _logoBlock(scheme),
        const SizedBox(height: 28),
        Text(
          'কোচিং ম্যানেজমেন্ট অ্যাপ',
          textAlign: TextAlign.center,
          style: GoogleFonts.hindSiliguri(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'মোবাইল নম্বর',
          style: GoogleFonts.hindSiliguri(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            hintText: '01XXXXXXXXX',
            hintStyle: GoogleFonts.nunito(color: scheme.onSurfaceVariant),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🇧🇩',
                    style: GoogleFonts.nunito(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+880',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: ref.watch(signInProvider).isLoading ? null : _sendOtp,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: scheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
          ),
          child: Text(
            'OTP পাঠাও',
            style: GoogleFonts.hindSiliguri(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep(ColorScheme scheme, bool loading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () {
              setState(() {
                _step = 1;
                _clearOtpFields();
                _resendTimer?.cancel();
                _resendSeconds = 0;
              });
            },
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.primary),
            tooltip: 'Back',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'OTP দিন',
          textAlign: TextAlign.center,
          style: GoogleFonts.hindSiliguri(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _maskedPhoneLine(),
          textAlign: TextAlign.center,
          style: GoogleFonts.hindSiliguri(
            fontSize: 14,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_otpLength, (i) => _otpBox(context, scheme, i)),
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: (_resendSeconds > 0 || loading) ? null : _resendOtp,
            child: Text(
              _resendSeconds > 0
                  ? 'পুনরায় OTP পাঠাও ($_resendSeconds)'
                  : 'পুনরায় OTP পাঠাও',
              style: GoogleFonts.hindSiliguri(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _resendSeconds > 0
                    ? scheme.onSurfaceVariant
                    : AppTheme.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _otpBox(BuildContext context, ColorScheme scheme, int index) {
    return SizedBox(
      width: 46,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocus[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        onChanged: (v) => _onOtpChanged(index, v),
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
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 48,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
