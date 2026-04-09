import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/widgets/theme_picker_sheet.dart';

/// Public entry: onboarding slides (no admin CMS). Continue → login.
class PublicHomeScreen extends ConsumerStatefulWidget {
  const PublicHomeScreen({super.key});

  @override
  ConsumerState<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _slides = <_Slide>[
  _Slide(
    icon: Icons.auto_awesome_rounded,
    title: 'Radiance-এ স্বাগতম',
    body:
        'আপনার কোচিং সেন্টারের কোর্স, পেমেন্ট ও শেখার সবকিছু এক জায়গায়।',
  ),
  _Slide(
    icon: Icons.school_outlined,
    title: 'কোর্স ও শিক্ষা',
    body:
        'কোর্স ম্যাটেরিয়াল, নোট ও পরীক্ষায় অংশ নিন—নিয়মিত আপডেট পাবেন।',
  ),
  _Slide(
    icon: Icons.payment_outlined,
    title: 'পেমেন্ট ও হিসাব',
    body:
        'ভাউচার ও মাসিক বিল স্বচ্ছভাবে দেখুন; সাপোর্ট দরকার হলে যোগাযোগ করুন।',
  ),
  _Slide(
    icon: Icons.forum_outlined,
    title: 'যোগাযোগ ও সাপোর্ট',
    body:
        'প্রশ্ন বা সমস্যা থাকলে সেন্টারের সাথে সরাসরি যোগাযোগ করতে পারবেন।',
  ),
];

class _PublicHomeScreenState extends ConsumerState<PublicHomeScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goLogin() {
    context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _index >= _slides.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Radiance', style: GoogleFonts.hindSiliguri()),
        actions: [
          IconButton(
            tooltip: 'থিম',
            onPressed: () => showThemePickerSheet(context, ref),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goLogin,
                      child: Text('লগইন', style: GoogleFonts.hindSiliguri()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: last ? _goLogin : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      child: Text(
                        last ? 'শুরু করুন' : 'পরবর্তী',
                        style: GoogleFonts.hindSiliguri(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          return PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final s = _slides[i];
              final pad = c.maxWidth < 400 ? 20.0 : 32.0;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: (c.maxWidth * 0.28).clamp(88.0, 120.0),
                      height: (c.maxWidth * 0.28).clamp(88.0, 120.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primaryContainer.withValues(alpha: 0.85),
                      ),
                      child: Icon(
                        s.icon,
                        size: 48,
                        color: scheme.primary,
                      ),
                    ),
                    SizedBox(height: c.maxHeight * 0.05),
                    Text(
                      s.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 15,
                        height: 1.45,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (last) ...[
                      const SizedBox(height: 28),
                      TextButton.icon(
                        onPressed: _goLogin,
                        icon: const Icon(Icons.login_rounded),
                        label: Text(
                          'লগইন / রেজিস্টার',
                          style: GoogleFonts.hindSiliguri(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
