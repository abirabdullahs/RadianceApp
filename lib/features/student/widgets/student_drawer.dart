import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/widgets/app_bar_drawer_leading.dart';
import '../../../app/widgets/theme_picker_sheet.dart';
import '../../auth/providers/auth_provider.dart' show currentUserProvider, signInProvider;
import '../../../shared/models/user_model.dart';

export '../../../app/widgets/app_bar_drawer_leading.dart'
    show AppBarDrawerLeading, AppBarDrawerAction, appBarDrawerLeading, leadingWidthForDrawer;

/// পুরনো কোডের সাথে সামঞ্জস্য — খালি; ড্রয়ার শুধু বামে [appBarDrawerLeading] দিয়ে খুলবে।
@Deprecated('Use appBarDrawerLeading + leadingWidthForDrawer on AppBar')
List<Widget> studentDrawerMenuActions(BuildContext context) => const [];

String _firstChar(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final it = t.runes.iterator;
  return it.moveNext() ? String.fromCharCode(it.current) : '?';
}

/// Shared drawer for all `/student/*` screens.
class StudentDrawer extends ConsumerWidget {
  const StudentDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final userAsync = ref.watch(currentUserProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          userAsync.when(
            data: (user) => _StudentDrawerHeader(user: user, scheme: scheme),
            loading: () => _DrawerHeaderLoading(scheme: scheme),
            error: (_, _) => _StudentDrawerHeader(user: null, scheme: scheme),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: Text('ড্যাশবোর্ড', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student');
            },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text('আমার কোর্স', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/courses');
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz_outlined),
            title: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/exams');
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: Text('ফলাফল', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/results');
            },
          ),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/payments');
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text('উপস্থিতি', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/attendance');
            },
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text('গ্রুপ চ্যাট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/community');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text('সন্দেহ সমাধান', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/doubts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: Text('প্রশ্ন ব্যাংক', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/qbank');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text('প্রোফাইল সম্পাদনা', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/profile/edit');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text('সেটিংস', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/student/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text('থিম ও রঙ', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              showThemePickerSheet(context, ref);
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(
              'লগআউট',
              style: GoogleFonts.hindSiliguri(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(signInProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerHeaderLoading extends StatelessWidget {
  const _DrawerHeaderLoading({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(color: scheme.primary),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}

class _StudentDrawerHeader extends StatelessWidget {
  const _StudentDrawerHeader({
    required this.user,
    required this.scheme,
  });

  final UserModel? user;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullNameBn.trim().isNotEmpty == true
        ? user!.fullNameBn.trim()
        : 'শিক্ষার্থী';
    final idLabel = user?.studentId?.trim().isNotEmpty == true
        ? user!.studentId!.trim()
        : (user?.phone ?? '—');
    final avatarUrl = user?.avatarUrl?.trim();

    return DrawerHeader(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: scheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Radiance',
            style: GoogleFonts.hindSiliguri(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'শিক্ষার্থী',
            style: GoogleFonts.hindSiliguri(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: avatarUrl, name: name, scheme: scheme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hindSiliguri(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'আইডি: $idLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.scheme,
  });

  final String? url;
  final String name;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final letter = _firstChar(name);
    final hasUrl = url != null && url!.isNotEmpty;

    return CircleAvatar(
      radius: 32,
      backgroundColor: scheme.onPrimary.withValues(alpha: 0.25),
      child: hasUrl
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                errorWidget: (_, _, _) => _LetterLabel(letter: letter),
              ),
            )
          : _LetterLabel(letter: letter),
    );
  }
}

class _LetterLabel extends StatelessWidget {
  const _LetterLabel({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: GoogleFonts.hindSiliguri(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
