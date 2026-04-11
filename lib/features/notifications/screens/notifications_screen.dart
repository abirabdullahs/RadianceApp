import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../admin/widgets/admin_responsive_scaffold.dart';
import '../../student/widgets/student_drawer.dart';
import '../providers/unread_notifications_provider.dart';
import '../repositories/notifications_repository.dart';

/// Lists [kTableNotifications] for the signed-in user.
///
/// [useAdminShell]: [AdminResponsiveScaffold] + admin drawer/rail; otherwise
/// student [Scaffold] + [StudentDrawer].
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.useAdminShell = false});

  final bool useAdminShell;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = NotificationsRepository().listForCurrentUser();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ref.read(notificationsRepositoryProvider).listForCurrentUser();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = _NotificationsListBody(
      future: _future,
      onReload: _reload,
      l10n: l10n,
    );

    if (widget.useAdminShell) {
      final scheme = Theme.of(context).colorScheme;
      return AdminResponsiveScaffold(
        title: Text(
          l10n.t('notifications_page_title'),
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              if (mounted) await _reload();
            },
            child: Text(
              l10n.t('mark_all_read'),
              style: GoogleFonts.hindSiliguri(color: scheme.onPrimary),
            ),
          ),
        ],
        body: body,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          l10n.t('notifications_page_title'),
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: [
          const AppBarDrawerAction(),
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              if (mounted) await _reload();
            },
            child: Text(
              l10n.t('mark_all_read'),
              style: GoogleFonts.hindSiliguri(color: scheme.onPrimary),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _NotificationsListBody extends ConsumerWidget {
  const _NotificationsListBody({
    required this.future,
    required this.onReload,
    required this.l10n,
  });

  final Future<List<Map<String, dynamic>>> future;
  final Future<void> Function() onReload;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd().add_jm();

    return RefreshIndicator(
      onRefresh: onReload,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${l10n.t('load_failed')}: ${snap.error}',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                ),
              ],
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      l10n.t('no_notifications'),
                      style: GoogleFonts.hindSiliguri(
                        color: scheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final id = n['id'] as String?;
              final read = n['is_read'] == true;
              final title = n['title']?.toString() ?? '';
              final body = n['body']?.toString() ?? '';
              final route = n['action_route']?.toString();
              final created = DateTime.tryParse(n['created_at']?.toString() ?? '');
              return Material(
                color: read ? null : scheme.primaryContainer.withValues(alpha: 0.55),
                child: InkWell(
                  onTap: () async {
                    final path = route?.trim();
                    final hasTarget = path != null && path.isNotEmpty;
                    // Navigate first: awaiting [onReload] before push rebuilds the list and
                    // can unmount this context, so [context.mounted] becomes false and
                    // navigation never runs.
                    if (hasTarget && context.mounted) {
                      context.push(path);
                    }
                    if (id != null) {
                      await ref.read(notificationsRepositoryProvider).markRead(id);
                      ref.invalidate(unreadNotificationCountProvider);
                    }
                    if (context.mounted) {
                      await onReload();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!read)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: scheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.hindSiliguri(
                                  fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 14,
                            fontWeight: read ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                        if (created != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            df.format(created.toLocal()),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
