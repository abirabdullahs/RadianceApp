import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/widgets/theme_picker_sheet.dart';
import '../../auth/providers/auth_provider.dart' show currentUserProvider, signInProvider;
import '../../../core/supabase_storage_image_url.dart';
import '../../../shared/models/user_model.dart';

export '../../../app/widgets/app_bar_drawer_leading.dart'
    show AppBarDrawerLeading, AppBarDrawerAction, appBarDrawerLeading, leadingWidthForDrawer;

@Deprecated('Use appBarDrawerLeading + leadingWidthForDrawer on AppBar')
List<Widget> teacherDrawerMenuActions(BuildContext context) => const [];

String _firstChar(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final it = t.runes.iterator;
  return it.moveNext() ? String.fromCharCode(it.current) : '?';
}

class TeacherDrawer extends ConsumerWidget {
  const TeacherDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final userAsync = ref.watch(currentUserProvider);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          userAsync.when(
            data: (user) => _TeacherDrawerHeader(user: user, scheme: scheme),
            loading: () => _TeacherHeaderLoading(scheme: scheme),
            error: (_, _) => _TeacherDrawerHeader(user: null, scheme: scheme),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text('সন্দেহ সমাধান', style: GoogleFonts.hindSiliguri()),
            onTap: () {
              Navigator.pop(context);
              context.go('/teacher');
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

class _TeacherHeaderLoading extends StatelessWidget {
  const _TeacherHeaderLoading({required this.scheme});

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

class _TeacherDrawerHeader extends StatelessWidget {
  const _TeacherDrawerHeader({
    required this.user,
    required this.scheme,
  });

  final UserModel? user;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullNameBn.trim().isNotEmpty == true
        ? user!.fullNameBn.trim()
        : 'শিক্ষক';
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
            'শিক্ষক',
            style: GoogleFonts.hindSiliguri(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TeacherAvatar(url: avatarUrl, name: name, scheme: scheme),
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

class _TeacherAvatar extends StatelessWidget {
  const _TeacherAvatar({
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
                imageUrl: supabaseStorageRenderImageUrl(url!, width: 128, height: 128),
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
