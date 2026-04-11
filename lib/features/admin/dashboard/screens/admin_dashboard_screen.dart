import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/notification_app_bar_action.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/dashboard_provider.dart';
import '../repositories/dashboard_repository.dart';

/// Admin home: stats, today overview, charts, quick actions, activity.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return AdminResponsiveScaffold(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Radiance',
            style: GoogleFonts.hindSiliguri(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            'Coaching Center · অ্যাডমিন',
            style: GoogleFonts.hindSiliguri(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(adminDashboardProvider),
        ),
        const NotificationAppBarAction(),
        PopupMenuButton<String>(
          tooltip: 'প্রোফাইল',
          onSelected: (v) async {
            if (v == 'logout') {
              await ref.read(signInProvider.notifier).signOut();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'logout',
              child: Text('লগআউট', style: GoogleFonts.hindSiliguri()),
            ),
          ],
          child: const Icon(Icons.account_circle_outlined),
        ),
      ],
      body: async.when(
        data: (data) => _DashboardBody(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'লোড করা যায়নি: $e',
              style: GoogleFonts.hindSiliguri(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final AdminDashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardProvider);
        await ref.read(adminDashboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HotShortcutsRow(
            onStudents: () => context.push('/admin/students'),
            onPayments: () => context.push('/admin/payments'),
            onAttendance: () => context.push('/admin/attendance'),
          ),
          const SizedBox(height: 12),
          _GreetingBlock(),
          const SizedBox(height: 16),
          SizedBox(
            height: 132,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _StatCard(
                  title: 'মোট শিক্ষার্থী',
                  value: '${data.totalStudents}',
                  subtitle: data.newStudentsThisWeek > 0
                      ? '↑ ${data.newStudentsThisWeek} নতুন (৭ দিন)'
                      : null,
                  icon: Icons.people_outline,
                  onTap: () => context.push('/admin/students'),
                ),
                _StatCard(
                  title: 'আজকের উপস্থিতি',
                  value: data.todayAttendancePct == null
                      ? '—'
                      : '${data.todayAttendancePct!.toStringAsFixed(0)}%',
                  subtitle: null,
                  icon: Icons.percent,
                  onTap: () => context.push('/admin/attendance'),
                ),
                _StatCard(
                  title: 'এই মাস আয়',
                  value: fmt.format(data.monthRevenue),
                  subtitle: data.revenueMoMPercent != null
                      ? 'আগের মাসের চেয়ে ${data.revenueMoMPercent! >= 0 ? '↑' : '↓'} ${data.revenueMoMPercent!.abs().toStringAsFixed(0)}%'
                      : null,
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => context.push('/admin/payments/reports'),
                ),
                _StatCard(
                  title: 'মোট বকেয়া',
                  value: fmt.format(data.totalDue),
                  subtitle: 'খোলা সূচি',
                  icon: Icons.warning_amber_outlined,
                  onTap: () => context.push('/admin/payments'),
                ),
                _StatCard(
                  title: 'খোলা Doubt',
                  value: '${data.openDoubtsCount}',
                  subtitle: 'দেখুন →',
                  icon: Icons.help_outline,
                  onTap: () => context.push('/admin/doubts'),
                ),
                _StatCard(
                  title: 'আসন্ন পরীক্ষা',
                  value: '${data.upcomingExamsCount}',
                  subtitle: 'সূচিত/লাইভ',
                  icon: Icons.quiz_outlined,
                  onTap: () => context.push('/admin/exams'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'দ্রুত কাজ',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _QuickActionCard(
                icon: Icons.person_add_alt_1,
                label: 'শিক্ষার্থী যোগ করুন',
                color: scheme.primary,
                onTap: () => context.push('/admin/students/add'),
              ),
              _QuickActionCard(
                icon: Icons.payments_outlined,
                label: 'পেমেন্ট নিন',
                color: AppTheme.accent,
                onTap: () => context.push('/admin/payments/add'),
              ),
              _QuickActionCard(
                icon: Icons.event_available_outlined,
                label: 'উপস্থিতি শুরু',
                color: Colors.teal,
                onTap: () => context.push('/admin/attendance'),
              ),
              _QuickActionCard(
                icon: Icons.edit_note,
                label: 'পরীক্ষা তৈরি',
                color: Colors.deepPurple,
                onTap: () => context.push('/admin/exams'),
              ),
              _QuickActionCard(
                icon: Icons.menu_book_outlined,
                label: 'ক্লাসনোট',
                color: Colors.indigo,
                onTap: () => context.push('/admin/courses'),
              ),
              _QuickActionCard(
                icon: Icons.help_outline,
                label: 'Doubt ইনবক্স',
                color: Colors.orange.shade800,
                onTap: () => context.push('/admin/doubts'),
              ),
              _QuickActionCard(
                icon: Icons.bar_chart,
                label: 'রিপোর্ট',
                color: Colors.blueGrey,
                onTap: () => context.push('/admin/payments/reports'),
              ),
              _QuickActionCard(
                icon: Icons.campaign_outlined,
                label: 'নোটিফিকেশন',
                color: scheme.secondary,
                onTap: () => context.push('/admin/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'আজকের অবস্থা',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _TodayAttendanceCard(rows: data.todayCourseAttendance),
          const SizedBox(height: 12),
          _TodayPaymentsCard(rows: data.todayPayments, totalFmt: fmt),
          const SizedBox(height: 12),
          _UpcomingExamsCard(exams: data.upcomingExams),
          const SizedBox(height: 12),
          _DoubtsPreviewCard(rows: data.doubtPreviews),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'মাসিক কালেকশন (৬ মাস)',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
              ),
              _ChartCourseDropdown(courseDistribution: data.courseDistribution),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _RevenueBarChart(monthly: data.monthlyRevenue),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'উপস্থিতি ট্রেন্ড (৩০ দিন)',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
              ),
              _ChartCourseDropdown(courseDistribution: data.courseDistribution),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _AttendanceLineChart(points: data.attendanceTrend),
          ),
          const SizedBox(height: 24),
          Text(
            'কোর্স অনুযায়ী শিক্ষার্থী',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _CoursePieChart(segments: data.courseDistribution),
          ),
          const SizedBox(height: 24),
          Text(
            'সাম্প্রতিক কার্যক্রম',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...data.recentActivity.map(
            (a) => ListTile(
              dense: true,
              leading: Icon(_activityIcon(a.kind), color: scheme.primary),
              title: Text(a.title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${a.subtitle} · ${_rel(a.at)}',
                style: GoogleFonts.hindSiliguri(fontSize: 12),
              ),
              onTap: a.route != null ? () => context.push(a.route!) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _rel(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inMinutes < 60) return '${diff.inMinutes} মি আগে';
    if (diff.inHours < 24) return '${diff.inHours} ঘণ্টা আগে';
    if (diff.inDays < 7) return '${diff.inDays} দিন আগে';
    return DateFormat.yMMMd().format(at);
  }
}

IconData _activityIcon(String kind) {
  switch (kind) {
    case 'payment':
      return Icons.payments_outlined;
    case 'student':
      return Icons.person_add_alt_1;
    case 'doubt':
      return Icons.help_outline;
    case 'exam':
      return Icons.quiz_outlined;
    default:
      return Icons.circle_notifications_outlined;
  }
}

class _HotShortcutsRow extends StatelessWidget {
  const _HotShortcutsRow({
    required this.onStudents,
    required this.onPayments,
    required this.onAttendance,
  });

  final VoidCallback onStudents;
  final VoidCallback onPayments;
  final VoidCallback onAttendance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _HotChip(label: 'শিক্ষার্থী', icon: Icons.person_search, onTap: onStudents, scheme: scheme),
        _HotChip(label: 'পেমেন্ট', icon: Icons.account_balance_wallet, onTap: onPayments, scheme: scheme),
        _HotChip(label: 'উপস্থিতি', icon: Icons.how_to_reg, onTap: onAttendance, scheme: scheme),
      ],
    );
  }
}

class _HotChip extends StatelessWidget {
  const _HotChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final g = _greetingEn(now.hour);
    final dateLine = DateFormat.yMMMMd().format(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$g, Admin! 👋',
          style: GoogleFonts.hindSiliguri(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateLine,
          style: GoogleFonts.hindSiliguri(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _greetingEn(int hour) {
    if (hour >= 6 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 18) return 'Good Afternoon';
    if (hour >= 18 && hour < 22) return 'Good Evening';
    return 'Good Night';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: AppTheme.accent),
                Text(title, style: GoogleFonts.hindSiliguri(fontSize: 11)),
                Text(
                  value,
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.hindSiliguri(fontSize: 10, color: Colors.green.shade800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.hindSiliguri(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCourseDropdown extends ConsumerWidget {
  const _ChartCourseDropdown({required this.courseDistribution});

  final List<Map<String, dynamic>> courseDistribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminChartCourseIdProvider);
    return DropdownButton<String?>(
      value: selected,
      hint: Text('কোর্স', style: GoogleFonts.hindSiliguri(fontSize: 12)),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('সব কোর্স', style: GoogleFonts.hindSiliguri(fontSize: 12)),
        ),
        for (final m in courseDistribution)
          DropdownMenuItem<String?>(
            value: m['id'] as String?,
            child: Text(
              '${m['name']}',
              style: GoogleFonts.hindSiliguri(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        ref.read(adminChartCourseIdProvider.notifier).state = v;
        ref.invalidate(adminDashboardProvider);
      },
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({required this.rows});

  final List<TodayCourseAttendanceRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_available, color: scheme.primary),
                const SizedBox(width: 8),
                Text('উপস্থিতি', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text('কোনো কোর্স নেই', style: GoogleFonts.hindSiliguri())
            else
              ...rows.map((r) {
                final total = r.enrolledTotal > 0 ? r.enrolledTotal : 1;
                final pct = r.hasSession ? (r.present / total).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.courseName,
                              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            r.hasSession
                                ? '${r.present}/${r.enrolledTotal}'
                                : '—/${r.enrolledTotal}',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r.hasSession
                                ? (r.isCompleted ? '✅' : '⏳')
                                : '—',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: r.hasSession ? pct : 0,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/admin/attendance'),
                child: Text('উপস্থিতি শুরু করুন →', style: GoogleFonts.hindSiliguri(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPaymentsCard extends StatelessWidget {
  const _TodayPaymentsCard({required this.rows, required this.totalFmt});

  final List<TodayPaymentRow> rows;
  final NumberFormat totalFmt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = rows.fold<double>(0, (a, b) => a + b.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'আজকের পেমেন্ট (${rows.length})',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text('আজ কোনো পেমেন্ট নেই', style: GoogleFonts.hindSiliguri())
            else
              ...rows.take(5).map((r) {
                final t = r.paidAt != null ? DateFormat.jm().format(r.paidAt!) : '';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.studentName, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(
                    '${r.paymentLabel ?? ''} · ${totalFmt.format(r.amount)}',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: Text(t, style: GoogleFonts.nunito(fontSize: 11)),
                );
              }),
            if (rows.isNotEmpty) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'আজ মোট: ${totalFmt.format(total)}',
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => context.push('/admin/payments'),
                    child: Text('সব দেখুন →', style: GoogleFonts.hindSiliguri(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpcomingExamsCard extends StatelessWidget {
  const _UpcomingExamsCard({required this.exams});

  final List<UpcomingExamSummary> exams;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd().add_jm();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('আসন্ন পরীক্ষা', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            if (exams.isEmpty)
              Text('কোনো সূচিত পরীক্ষা নেই', style: GoogleFonts.hindSiliguri())
            else
              ...exams.take(4).map((e) {
                final when = e.startTime ?? e.examDate;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.examMode == 'online' ? Icons.language : Icons.assignment_outlined,
                    size: 20,
                  ),
                  title: Text(e.title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${e.courseName} · ${when != null ? df.format(when.toLocal()) : ''}',
                    style: GoogleFonts.hindSiliguri(fontSize: 12),
                  ),
                  onTap: () => context.push('/admin/exams'),
                );
              }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/admin/exams'),
                child: Text('পরীক্ষা ব্যবস্থাপনা →', style: GoogleFonts.hindSiliguri(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoubtsPreviewCard extends StatelessWidget {
  const _DoubtsPreviewCard({required this.rows});

  final List<DoubtPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: scheme.primary),
                const SizedBox(width: 8),
                Text('খোলা Doubt', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text('কোনো খোলা doubt নেই', style: GoogleFonts.hindSiliguri())
            else
              ...rows.map((r) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${r.studentName} · ${r.titleSnippet}',
                    style: GoogleFonts.hindSiliguri(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.push('/admin/doubts/${r.id}'),
                );
              }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/admin/doubts'),
                child: Text('সব Doubts →', style: GoogleFonts.hindSiliguri(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.monthly});

  final List<Map<String, dynamic>> monthly;

  @override
  Widget build(BuildContext context) {
    if (monthly.isEmpty) {
      return Center(child: Text('কোনো ডেটা নেই', style: GoogleFonts.hindSiliguri()));
    }
    final maxY = monthly
        .map((e) => (e['amount'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 1.0 : maxY * 1.1;

    return BarChart(
      BarChartData(
        maxY: top,
        barGroups: [
          for (var i = 0; i < monthly.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (monthly[i]['amount'] as num?)?.toDouble() ?? 0,
                  color: Theme.of(context).colorScheme.primary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
                final label = monthly[i]['label'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _AttendanceLineChart extends StatelessWidget {
  const _AttendanceLineChart({required this.points});

  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(child: Text('কোনো ডেটা নেই', style: GoogleFonts.hindSiliguri()));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), (points[i]['pct'] as num?)?.toDouble() ?? 0),
            ],
            color: AppTheme.accent,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Text(
                  '${points[i]['label']}',
                  style: const TextStyle(fontSize: 8),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _CoursePieChart extends StatelessWidget {
  const _CoursePieChart({required this.segments});

  final List<Map<String, dynamic>> segments;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return Center(
        child: Text('নথিভুক্ত কোর্স নেই', style: GoogleFonts.hindSiliguri()),
      );
    }
    final total = segments.fold<double>(
      0,
      (a, s) => a + ((s['value'] as num?)?.toDouble() ?? 0),
    );
    if (total <= 0) {
      return Center(child: Text('০ জন', style: GoogleFonts.hindSiliguri()));
    }
    final colors = [
      Theme.of(context).colorScheme.primary,
      AppTheme.accent,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.indigo,
    ];
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < segments.length; i++) {
      final v = (segments[i]['value'] as num?)?.toDouble() ?? 0;
      final pct = v / total;
      sections.add(
        PieChartSectionData(
          value: v,
          title: '${(pct * 100).toStringAsFixed(0)}%',
          color: colors[i % colors.length],
          radius: 80,
          titleStyle: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      );
    }
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 36,
        sectionsSpace: 2,
      ),
    );
  }
}
