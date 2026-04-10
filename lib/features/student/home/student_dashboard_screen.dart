import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/notification_app_bar_action.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/payment_ledger_model.dart';
import '../../../shared/models/payment_schedule_model.dart';
import '../../admin/payments/repositories/payment_repository.dart';
import '../../admin/students/repositories/student_repository.dart';
import '../../doubts/repositories/doubt_repository.dart';
import '../notes/repositories/notes_repository.dart';
import '../widgets/student_drawer.dart';

/// Student home: dynamic summary + grid menu to all student routes.
class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final student = await StudentRepository().getStudentById(uid);
    final month = DateTime.now();
    final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final att = await StudentRepository().getStudentAttendanceSummary(uid, ym);
    final paymentRepo = PaymentRepository();
    final dues = await paymentRepo.getPaymentSchedule(studentId: uid, onlyOpen: true);
    final openDues = dues.where((d) => d.status != PaymentScheduleStatus.paid).toList();
    final openDueTotal = openDues.fold<double>(
      0,
      (a, d) => a + (d.remainingAmount > 0 ? d.remainingAmount : d.amount),
    );
    final payments = await paymentRepo.getPaymentLedger(studentId: uid);
    final lastPayment = payments.isNotEmpty ? payments.first : null;
    final lastLecture = await NotesRepository().getLatestLectureForCurrentStudent();
    var solvedDoubts = 0;
    try {
      solvedDoubts = await DoubtRepository().countSolvedForStudent(uid);
    } catch (_) {
      // Table/migration missing or RLS — don't break whole dashboard.
    }

    return _DashData(
      name: student.fullNameBn,
      college: student.college,
      attendancePct: att['percentage'] as double?,
      openDuesCount: openDues.length,
      openDueTotal: openDueTotal,
      lastPayment: lastPayment,
      lastLectureTitle: lastLecture?['title'] as String?,
      lastLectureChapterId: lastLecture?['chapter_id'] as String?,
      solvedDoubtsCount: solvedDoubts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final dateFmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('ড্যাশবোর্ড', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        actions: [
          const AppBarDrawerAction(),
          const NotificationAppBarAction(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'রিফ্রেশ',
            onPressed: () {
              setState(() {
                _future = _load();
              });
            },
          ),
        ],
      ),
      drawer: const StudentDrawer(),
      body: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'লোড করা যায়নি: ${snap.error}',
                  style: GoogleFonts.hindSiliguri(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final d = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'হ্যালো, ${d.name}!',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.themePrimary,
                  ),
                ),
                if (d.college != null && d.college!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    d.college!.trim(),
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'সংক্ষিপ্ত তথ্য',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.play_circle_outline,
                  title: 'শেষ লেকচার',
                  subtitle: d.lastLectureTitle ?? 'কোনো লেকচার পাওয়া যায়নি',
                  onTap: d.lastLectureChapterId != null
                      ? () => context.push('/student/notes/${d.lastLectureChapterId}')
                      : null,
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.receipt_long,
                  title: 'শেষ পেমেন্ট',
                  subtitle: d.lastPayment == null
                      ? 'কোনো পেমেন্ট নেই'
                      : '${fmt.format(d.lastPayment!.amountPaid)} · ${d.lastPayment!.paidAt != null ? dateFmt.format(d.lastPayment!.paidAt!.toLocal()) : ''}',
                  onTap: () => context.push('/student/payments'),
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'বকেয়া',
                  subtitle: d.openDuesCount == 0
                      ? 'কোনো বকেয়া নেই'
                      : '${d.openDuesCount} টি · মোট ${fmt.format(d.openDueTotal)}',
                  onTap: () => context.push('/student/payments'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'এই মাস উপস্থিতি',
                        value: d.attendancePct == null
                            ? '—'
                            : '${d.attendancePct!.toStringAsFixed(0)}%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'খোলা বকেয়া (সংখ্যা)',
                        value: '${d.openDuesCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.help_outline,
                  title: 'সন্দেহ সমাধান',
                  subtitle: '${d.solvedDoubtsCount} টি সন্দেহ সমাধান হয়েছে',
                  onTap: () => context.push('/student/doubts'),
                ),
                const SizedBox(height: 24),
                Text(
                  'মেনু',
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
                      label: 'ক্লাসনোট',
                      onTap: () => context.push('/student/courses'),
                    ),
                    _MenuSquare(
                      icon: Icons.quiz_outlined,
                      label: 'পরীক্ষা',
                      onTap: () => context.push('/student/exams'),
                    ),
                    _MenuSquare(
                      icon: Icons.emoji_events_outlined,
                      label: 'ফলাফল',
                      onTap: () => context.push('/student/results'),
                    ),
                    _MenuSquare(
                      icon: Icons.payments_outlined,
                      label: 'পেমেন্ট',
                      onTap: () => context.push('/student/payments'),
                    ),
                    _MenuSquare(
                      icon: Icons.event_available_outlined,
                      label: 'উপস্থিতি',
                      onTap: () => context.push('/student/attendance'),
                    ),
                    _MenuSquare(
                      icon: Icons.groups_outlined,
                      label: 'গ্রুপ',
                      onTap: () => context.push('/student/community'),
                    ),
                    _MenuSquare(
                      icon: Icons.library_books_outlined,
                      label: 'প্রশ্ন ব্যাংক',
                      onTap: () => context.push('/student/qbank'),
                    ),
                    _MenuSquare(
                      icon: Icons.help_outline,
                      label: 'সন্দেহ সমাধান',
                      onTap: () => context.push('/student/doubts'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashData {
  const _DashData({
    required this.name,
    this.college,
    required this.attendancePct,
    required this.openDuesCount,
    required this.openDueTotal,
    this.lastPayment,
    this.lastLectureTitle,
    this.lastLectureChapterId,
    required this.solvedDoubtsCount,
  });

  final String name;
  final String? college;
  final double? attendancePct;
  final int openDuesCount;
  final double openDueTotal;
  final PaymentLedgerModel? lastPayment;
  final String? lastLectureTitle;
  final String? lastLectureChapterId;
  final int solvedDoubtsCount;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.hindSiliguri(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 32, color: context.themePrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
          ],
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: child);
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
