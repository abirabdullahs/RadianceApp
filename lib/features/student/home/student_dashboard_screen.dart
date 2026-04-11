import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../app/theme.dart';
import '../../../shared/models/exam_model.dart';
import '../../../app/widgets/notification_app_bar_action.dart';
import '../screens/student_route_screens.dart' show showStudentQbankSearchSheet;
import '../widgets/student_drawer.dart';
import 'student_dashboard_provider.dart';

String _greetingPrefix(AppLocalizations l10n) {
  final h = DateTime.now().hour;
  if (h >= 6 && h < 12) return l10n.t('greet_morning');
  if (h >= 12 && h < 18) return l10n.t('greet_afternoon');
  if (h >= 18 && h < 22) return l10n.t('greet_evening');
  return l10n.t('greet_night');
}

/// Student home: profile, alerts, stats, courses, suggestion, activity.
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentDashboardProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(l10n.t('home'), style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: l10n.t('search'),
            icon: const Icon(Icons.search),
            onPressed: () async {
              final r = await showStudentQbankSearchSheet(context);
              if (r == null || !context.mounted) return;
              context.push('/student/qbank/practice/${r.chapterId}');
            },
          ),
          const AppBarDrawerAction(),
          const NotificationAppBarAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.t('refresh'),
            onPressed: () => ref.invalidate(studentDashboardProvider),
          ),
        ],
      ),
      drawer: const StudentDrawer(),
      body: async.when(
        data: (d) => _DashboardScrollBody(data: d, l10n: l10n),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${l10n.t('load_failed')}: $e',
              style: GoogleFonts.hindSiliguri(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardScrollBody extends ConsumerWidget {
  const _DashboardScrollBody({required this.data, required this.l10n});

  final StudentDashboardData data;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final s = data.student;
    final sid = s.studentId?.trim();
    final idLabel =
        (sid != null && sid.isNotEmpty) ? sid : (s.phone.isNotEmpty ? s.phone : '—');

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studentDashboardProvider);
        await ref.read(studentDashboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(
            greetingPrefix: _greetingPrefix(l10n),
            name: s.fullNameBn,
            idLabel: idLabel,
            subtitle: s.college?.trim().isNotEmpty == true ? s.college!.trim() : null,
            avatarUrl: s.avatarUrl,
          ),
          const SizedBox(height: 12),
          if (data.alerts.isNotEmpty) ...[
            SizedBox(
              height: data.alerts.length == 1 ? 72 : 88,
              child: PageView.builder(
                itemCount: data.alerts.length,
                itemBuilder: (context, i) {
                  final a = data.alerts[i];
                  final scheme = Theme.of(context).colorScheme;
                  final color = a.kind == StudentDashboardAlertKind.paymentDue
                      ? scheme.error
                      : (a.kind == StudentDashboardAlertKind.attendanceLow
                          ? Colors.orange.shade800
                          : scheme.primary);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => context.push(a.route),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: color, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  a.message,
                                  style: GoogleFonts.hindSiliguri(
                                    fontSize: 13,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                a.actionLabel,
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          Text(
            l10n.t('summary'),
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 128,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _MiniStatCard(
                  title: l10n.t('attendance'),
                  line1: data.paymentMonthLabel,
                  line2: data.attendanceTotal > 0
                      ? '${data.attendancePresent}/${data.attendanceTotal}'
                      : '—',
                  line3: data.attendancePct != null
                      ? '${data.attendancePct!.toStringAsFixed(0)}%'
                      : '—',
                  onTap: () => context.push('/student/attendance'),
                ),
                _MiniStatCard(
                  title: l10n.t('last_result'),
                  line1: data.latestResult?.examTitle ?? '—',
                  line2: data.latestResult != null
                      ? '${data.latestResult!.score.toStringAsFixed(0)}/${data.latestResult!.totalMarks.toStringAsFixed(0)}'
                      : '—',
                  line3: data.latestResult != null
                      ? '${data.latestResult!.percentage.toStringAsFixed(0)}%${data.latestResult!.rank != null ? ' · ${l10n.t('rank_prefix')}${data.latestResult!.rank}' : ''}'
                      : '',
                  onTap: () => context.push('/student/results'),
                ),
                _MiniStatCard(
                  title: l10n.t('payments'),
                  line1: data.paymentMonthLabel,
                  line2: data.paymentOk
                      ? l10n.t('paid')
                      : '${data.openDuesCount} ${l10n.t('dues_label')}',
                  line3: data.openDueTotal > 0 ? fmt.format(data.openDueTotal) : '✓',
                  onTap: () => context.push('/student/payments'),
                ),
                _MiniStatCard(
                  title: l10n.t('doubts_title'),
                  line1: l10n.t('doubts_open').replaceAll('{n}', '${data.openDoubts}'),
                  line2: l10n.t('doubts_replying').replaceAll('{n}', '${data.inProgressDoubts}'),
                  line3: l10n.t('doubts_solved').replaceAll('{n}', '${data.solvedDoubtsCount}'),
                  onTap: () => context.push('/student/doubts'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.t('upcoming'),
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (data.upcomingExams.isEmpty)
            Text(l10n.t('no_upcoming_exams'), style: GoogleFonts.hindSiliguri())
          else
            ...data.upcomingExams.take(4).map((e) => _ExamTile(exam: e)),
          const SizedBox(height: 20),
          Text(
            l10n.t('my_courses'),
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (data.enrolledCourses.isEmpty)
            Text(l10n.t('no_courses_enrolled'), style: GoogleFonts.hindSiliguri())
          else
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.enrolledCourses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final t = data.enrolledCourses[i];
                  final c = t.course;
                  final pct = t.notesProgressPct.clamp(0, 100);
                  return SizedBox(
                    width: 220,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/student/courses/${c.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Text(
                                '${l10n.t('notes_progress')}: ${pct.toStringAsFixed(0)}%',
                                style: GoogleFonts.nunito(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(value: pct / 100.0, minHeight: 5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Text(
            l10n.t('daily_suggestion'),
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.dailySuggestion,
                      style: GoogleFonts.hindSiliguri(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.t('recent_activity'),
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (data.recentActivity.isEmpty)
            Text(l10n.t('no_recent_activity'), style: GoogleFonts.hindSiliguri())
          else
            ...data.recentActivity.map(
              (a) => ListTile(
                dense: true,
                leading: Text(a.icon, style: const TextStyle(fontSize: 20)),
                title: Text(a.title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
                subtitle: Text(a.subtitle, style: GoogleFonts.hindSiliguri(fontSize: 12)),
                onTap: () => context.push(a.route),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            l10n.t('menu_grid'),
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _MenuSquare(
                icon: Icons.school_outlined,
                label: l10n.t('class_notes'),
                onTap: () => context.push('/student/courses'),
              ),
              _MenuSquare(
                icon: Icons.quiz_outlined,
                label: l10n.t('exams'),
                onTap: () => context.push('/student/exams'),
              ),
              _MenuSquare(
                icon: Icons.emoji_events_outlined,
                label: l10n.t('results'),
                onTap: () => context.push('/student/results'),
              ),
              _MenuSquare(
                icon: Icons.payments_outlined,
                label: l10n.t('payments'),
                onTap: () => context.push('/student/payments'),
              ),
              _MenuSquare(
                icon: Icons.event_available_outlined,
                label: l10n.t('attendance'),
                onTap: () => context.push('/student/attendance'),
              ),
              _MenuSquare(
                icon: Icons.groups_outlined,
                label: l10n.t('group_short'),
                onTap: () => context.push('/student/community'),
              ),
              _MenuSquare(
                icon: Icons.library_books_outlined,
                label: l10n.t('question_bank'),
                onTap: () => context.push('/student/qbank'),
              ),
              _MenuSquare(
                icon: Icons.help_outline,
                label: l10n.t('doubt_solve'),
                onTap: () => context.push('/student/doubts'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.greetingPrefix,
    required this.name,
    required this.idLabel,
    this.subtitle,
    this.avatarUrl,
  });

  final String greetingPrefix;
  final String name;
  final String idLabel;
  final String? subtitle;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: avatarUrl != null && avatarUrl!.trim().isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl!.trim())
                  : null,
              child: avatarUrl == null || avatarUrl!.trim().isEmpty
                  ? Icon(Icons.person, size: 36, color: scheme.primary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greetingPrefix $name! 👋',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.themePrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(idLabel, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: GoogleFonts.hindSiliguri(fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.line1,
    required this.line2,
    required this.line3,
    required this.onTap,
  });

  final String title;
  final String line1;
  final String line2;
  final String line3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 132,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.hindSiliguri(fontSize: 11)),
                const Spacer(),
                Text(line1, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.hindSiliguri(fontSize: 11)),
                Text(line2, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13)),
                if (line3.isNotEmpty)
                  Text(line3, style: GoogleFonts.nunito(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    final when = exam.startTime ?? exam.examDate;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(exam.examMode == 'online' ? Icons.language : Icons.assignment_outlined),
        title: Text(exam.title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        subtitle: Text(
          when != null ? df.format(when.toLocal()) : exam.status,
          style: GoogleFonts.nunito(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/student/exams'),
      ),
    );
  }
}

class _MenuSquare extends StatelessWidget {
  const _MenuSquare({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: context.themePrimary),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.hindSiliguri(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
