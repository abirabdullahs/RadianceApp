import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/i18n/app_localizations.dart';
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
    return Drawer(
      child: const StudentMenuContent(closeFirst: true),
    );
  }
}

class StudentMenuContent extends ConsumerWidget {
  const StudentMenuContent({super.key, required this.closeFirst});

  final bool closeFirst;

  void _closeIfNeeded(BuildContext context) {
    if (closeFirst && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        userAsync.when(
          data: (user) => _StudentDrawerHeader(user: user, scheme: scheme),
          loading: () => _DrawerHeaderLoading(scheme: scheme),
          error: (_, _) => _StudentDrawerHeader(user: null, scheme: scheme),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard_outlined),
          title: Text(l10n.t('dashboard'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student');
          },
        ),
        ListTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(l10n.t('my_courses'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/courses');
          },
        ),
        ListTile(
          leading: const Icon(Icons.quiz_outlined),
          title: Text(l10n.t('exams'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/exams');
          },
        ),
        ListTile(
          leading: const Icon(Icons.emoji_events_outlined),
          title: Text(l10n.t('results'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/results');
          },
        ),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(l10n.t('payments'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/payments');
          },
        ),
        ListTile(
          leading: const Icon(Icons.event_available_outlined),
          title: Text(l10n.t('attendance'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/attendance');
          },
        ),
        ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(l10n.t('group_chat'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/community');
          },
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(l10n.t('doubt_solve'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/doubts');
          },
        ),
        ListTile(
          leading: const Icon(Icons.library_books_outlined),
          title: Text(l10n.t('question_bank'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/qbank');
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(l10n.t('edit_profile'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/profile/edit');
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.t('settings'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            context.go('/student/settings');
          },
        ),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(l10n.t('theme_and_colors'), style: GoogleFonts.hindSiliguri()),
          onTap: () {
            _closeIfNeeded(context);
            showThemePickerSheet(context, ref);
          },
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: Text(
            l10n.t('logout'),
            style: GoogleFonts.hindSiliguri(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () async {
            _closeIfNeeded(context);
            await ref.read(signInProvider.notifier).signOut();
          },
        ),
      ],
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
        : AppLocalizations.of(context).t('student');
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
            AppLocalizations.of(context).t('student'),
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
                      '${AppLocalizations.of(context).t('id_prefix')}: $idLabel',
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
