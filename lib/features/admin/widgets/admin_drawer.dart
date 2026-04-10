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
List<Widget> adminDrawerMenuActions(BuildContext context) => const [];

String _firstChar(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final it = t.runes.iterator;
  return it.moveNext() ? String.fromCharCode(it.current) : '?';
}

/// Shared navigation drawer for all `/admin/*` screens.
class AdminDrawer extends ConsumerWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final userAsync = ref.watch(currentUserProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          userAsync.when(
            data: (user) => _AdminDrawerHeader(user: user, scheme: scheme),
            loading: () => _AdminHeaderLoading(scheme: scheme),
            error: (_, _) => _AdminDrawerHeader(user: null, scheme: scheme),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text('ড্যাশবোর্ড', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin');
            },
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: Text('কোর্স', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/courses');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('শিক্ষার্থী', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/students');
            },
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/payments');
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: Text('উপস্থিতি', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/attendance');
            },
          ),
          ListTile(
            leading: const Icon(Icons.quiz),
            title: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/exams');
            },
          ),
          ListTile(
            leading: const Icon(Icons.web),
            title: Text('হোম পেজ কন্টেন্ট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/cms');
            },
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: Text('কোর্স চ্যাট', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/course-chats');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text('সন্দেহ সমাধান', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/doubts');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text('থিম ও রঙ', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              showThemePickerSheet(context, ref);
            },
          ),
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

class _AdminHeaderLoading extends StatelessWidget {
  const _AdminHeaderLoading({required this.scheme});

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

class _AdminDrawerHeader extends StatelessWidget {
  const _AdminDrawerHeader({
    required this.user,
    required this.scheme,
  });

  final UserModel? user;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullNameBn.trim().isNotEmpty == true
        ? user!.fullNameBn.trim()
        : 'অ্যাডমিন';
    final sub = user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
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
            'অ্যাডমিন',
            style: GoogleFonts.hindSiliguri(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminAvatar(url: avatarUrl, name: name, scheme: scheme),
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
                      sub,
                      maxLines: 2,
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

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({
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
