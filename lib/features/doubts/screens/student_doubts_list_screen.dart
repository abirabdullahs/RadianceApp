import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/notification_app_bar_action.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/doubt_thread_model.dart';
import '../repositories/doubt_repository.dart';
import '../../student/widgets/student_drawer.dart';

/// Student: own doubts (newest first); FAB for new doubt; optional purge prompt.
class StudentDoubtsListScreen extends StatefulWidget {
  const StudentDoubtsListScreen({super.key});

  @override
  State<StudentDoubtsListScreen> createState() => _StudentDoubtsListScreenState();
}

class _StudentDoubtsListScreenState extends State<StudentDoubtsListScreen> {
  late Future<List<DoubtThreadModel>> _future;
  late Future<Map<String, int>> _statsFuture;
  final _repo = DoubtRepository();

  @override
  void initState() {
    super.initState();
    _future = _repo.listMyDoubts();
    final uid = supabaseClient.auth.currentUser?.id;
    _statsFuture = uid == null
        ? Future.value({'totalSubmitted': 0, 'totalSolved': 0})
        : _repo.getMyStats(uid);
  }

  Future<void> _confirmPurge(DoubtThreadModel d) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('doubt_purge_chat_title'), style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text(
          l10n.t('doubt_purge_thread_body'),
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_no'), style: GoogleFonts.hindSiliguri()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.t('doubt_purge_confirm'), style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.purgeMessages(d.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('doubt_messages_deleted'), style: GoogleFonts.hindSiliguri())),
      );
      setState(() {
        _future = _repo.listMyDoubts();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).t('failed')}: $e', style: GoogleFonts.hindSiliguri())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(l10n.t('doubt_solve'), style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        actions: const [AppBarDrawerAction(), NotificationAppBarAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student/doubts/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('doubt_new_short'), style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<DoubtThreadModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(l10n.t('load_failed'), style: GoogleFonts.hindSiliguri()));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.t('doubt_list_empty'),
                  style: GoogleFonts.hindSiliguri(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final uid = supabaseClient.auth.currentUser?.id;
              setState(() {
                _future = _repo.listMyDoubts();
                if (uid != null) _statsFuture = _repo.getMyStats(uid);
              });
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return FutureBuilder<Map<String, int>>(
                    future: _statsFuture,
                    builder: (context, statsSnap) {
                      final submitted = statsSnap.data?['totalSubmitted'] ?? 0;
                      final solved = statsSnap.data?['totalSolved'] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(label: l10n.t('doubt_stat_submitted'), value: '$submitted'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(label: l10n.t('doubt_stat_solved_count'), value: '$solved'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                final d = list[i - 1];
                final preview = d.problemDescription.length > 100
                    ? '${d.problemDescription.substring(0, 100)}…'
                    : d.problemDescription;
                return ListTile(
                  leading: Icon(
                    d.status == DoubtStatus.solved ? Icons.check_circle : Icons.help_outline,
                    color: d.status == DoubtStatus.solved ? Colors.green : context.themePrimary,
                  ),
                  title: Text(
                    d.title.isNotEmpty ? d.title : preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _statusText(l10n, d.status),
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'purge') _confirmPurge(d);
                      if (v == 'join' && d.meetingLink != null && d.meetingLink!.isNotEmpty) {
                        context.push('/student/doubts/${d.id}');
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (d.status == DoubtStatus.meetingScheduled)
                        PopupMenuItem(
                          value: 'join',
                          child: Text(l10n.t('doubt_view_meeting'), style: GoogleFonts.hindSiliguri()),
                        ),
                      PopupMenuItem(
                        value: 'purge',
                        child: Text(l10n.t('doubt_purge_chat'), style: GoogleFonts.hindSiliguri()),
                      ),
                    ],
                  ),
                  onTap: () => context.push('/student/doubts/${d.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _statusText(AppLocalizations l10n, DoubtStatus s) {
    switch (s) {
      case DoubtStatus.open:
        return l10n.t('doubt_status_open');
      case DoubtStatus.inProgress:
        return l10n.t('doubt_status_in_progress');
      case DoubtStatus.meetingScheduled:
        return l10n.t('doubt_status_meeting');
      case DoubtStatus.solved:
        return l10n.t('doubt_status_solved');
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.hindSiliguri(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
