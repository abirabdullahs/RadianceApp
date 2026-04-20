import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/payment_schedule_model.dart';
import '../../../../shared/models/payment_type_model.dart';
import '../../../../shared/models/result_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/repositories/course_repository.dart';
import '../../payments/repositories/payment_repository.dart';
import '../repositories/student_repository.dart';

final _studentProfileProvider =
    FutureProvider.autoDispose.family<_StudentProfileBundle, String>((ref, id) async {
  final repo = StudentRepository();
  final courseRepo = CourseRepository();
  final payRepo = PaymentRepository();

  final student = await repo.getStudentById(id);
  final enrollments = await repo.getStudentEnrollments(id);
  final payments = await repo.getStudentPayments(id);
  final results = await repo.getStudentResults(id);
  final openSchedules =
      await payRepo.getPaymentSchedule(studentId: id, onlyOpen: true);
  final paymentTypes = await payRepo.listPaymentTypes(activeOnly: false);

  final month = DateTime.now();
  final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  final att = await repo.getStudentAttendanceSummary(id, ym);

  final courseIds = <String>{
    ...enrollments.map((e) => e.courseId),
    ...openSchedules.map((s) => s.courseId),
  };
  final courseNames = <String, String>{};
  for (final cid in courseIds) {
    try {
      final c = await courseRepo.getCourseById(cid);
      courseNames[cid] = c.name;
    } catch (_) {
      courseNames[cid] = cid;
    }
  }
  return _StudentProfileBundle(
    student: student,
    enrollments: enrollments,
    courseNames: courseNames,
    payments: payments,
    results: results,
    attendanceSummary: att,
    openSchedules: openSchedules,
    paymentTypes: paymentTypes,
  );
});

class _StudentProfileBundle {
  const _StudentProfileBundle({
    required this.student,
    required this.enrollments,
    required this.courseNames,
    required this.payments,
    required this.results,
    required this.attendanceSummary,
    required this.openSchedules,
    required this.paymentTypes,
  });

  final UserModel student;
  final List<EnrollmentModel> enrollments;
  final Map<String, String> courseNames;
  final List<PaymentModel> payments;
  final List<ResultModel> results;
  final Map<String, dynamic> attendanceSummary;
  final List<PaymentScheduleModel> openSchedules;
  final List<PaymentTypeModel> paymentTypes;
}

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_studentProfileProvider(studentId));

    return async.when(
      data: (b) {
        final u = b.student;
        return DefaultTabController(
          length: 4,
          child: AdminResponsiveScaffold(
            title: Text(u.fullNameBn, style: GoogleFonts.hindSiliguri()),
            bottom: TabBar(
              isScrollable: true,
              tabs: [
                Tab(child: Text('তথ্য', style: GoogleFonts.hindSiliguri())),
                Tab(child: Text('কোর্স', style: GoogleFonts.hindSiliguri())),
                Tab(child: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri())),
                Tab(child: Text('ফলাফল', style: GoogleFonts.hindSiliguri())),
              ],
            ),
            body: TabBarView(
              children: [
                _InfoTab(u: u),
                _CoursesTab(
                  enrollments: b.enrollments,
                  courseNames: b.courseNames,
                  studentId: studentId,
                ),
                _PaymentsTab(
                  studentId: studentId,
                  payments: b.payments,
                  openSchedules: b.openSchedules,
                  paymentTypes: b.paymentTypes,
                  courseNames: b.courseNames,
                ),
                _ResultsTab(
                  results: b.results,
                  attendanceSummary: b.attendanceSummary,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => AdminResponsiveScaffold(
        title: Text('লোড হচ্ছে…', style: GoogleFonts.hindSiliguri()),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AdminResponsiveScaffold(
        title: Text('ত্রুটি', style: GoogleFonts.hindSiliguri()),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.u});

  final UserModel u;

  @override
  Widget build(BuildContext context) {
    final dob = u.dateOfBirth != null
        ? DateFormat.yMMMd().format(u.dateOfBirth!)
        : '—';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: Text('ফোন', style: GoogleFonts.hindSiliguri()),
          subtitle: Text(u.phone, style: GoogleFonts.nunito()),
        ),
        ListTile(
          title: Text('অভিভাবকের ফোন', style: GoogleFonts.hindSiliguri()),
          subtitle: Text(u.guardianPhone ?? '—', style: GoogleFonts.nunito()),
        ),
        ListTile(
          title: Text('আইডি', style: GoogleFonts.hindSiliguri()),
          subtitle: Text(u.studentId ?? '—', style: GoogleFonts.nunito()),
        ),
        ListTile(
          title: Text('জন্মতারিখ', style: GoogleFonts.hindSiliguri()),
          subtitle: Text(dob, style: GoogleFonts.nunito()),
        ),
        ListTile(
          title: Text('কলেজ / স্কুল', style: GoogleFonts.hindSiliguri()),
          subtitle: Text(u.college ?? '—', style: GoogleFonts.hindSiliguri()),
        ),
        ListTile(
          title: Text('ঠিকানা', style: GoogleFonts.hindSiliguri()),
          subtitle: Text(u.address ?? '—', style: GoogleFonts.hindSiliguri()),
        ),
      ],
    );
  }
}

class _CoursesTab extends ConsumerWidget {
  const _CoursesTab({
    required this.enrollments,
    required this.courseNames,
    required this.studentId,
  });

  final List<EnrollmentModel> enrollments;
  final Map<String, String> courseNames;
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: FilledButton.icon(
            onPressed: () => _showEnrollSheet(context, ref, studentId),
            icon: const Icon(Icons.add),
            label: Text('কোর্সে ভর্তি', style: GoogleFonts.hindSiliguri()),
            style: FilledButton.styleFrom(backgroundColor: context.themePrimary),
          ),
        ),
        Expanded(
          child: enrollments.isEmpty
              ? Center(
                  child: Text('কোনো কোর্স নেই', style: GoogleFonts.hindSiliguri()),
                )
              : ListView.builder(
                  itemCount: enrollments.length,
                  itemBuilder: (context, i) {
                    final e = enrollments[i];
                    return ListTile(
                      title: Text(
                        courseNames[e.courseId] ?? e.courseId,
                        style: GoogleFonts.hindSiliguri(),
                      ),
                      subtitle: Text(
                        e.status.toJson(),
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showEnrollSheet(
    BuildContext context,
    WidgetRef ref,
    String sid,
  ) async {
    final courses = await CourseRepository().getCourses();
    final active = courses.where((c) => c.isActive).toList();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'কোর্স বেছে নিন',
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              for (final c in active)
                ListTile(
                  title: Text(c.name, style: GoogleFonts.hindSiliguri()),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await StudentRepository().enrollStudentInCourse(sid, c.id);
                      ref.invalidate(_studentProfileProvider(sid));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'ভর্তি সম্পন্ন',
                              style: GoogleFonts.hindSiliguri(),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab({
    required this.studentId,
    required this.payments,
    required this.openSchedules,
    required this.paymentTypes,
    required this.courseNames,
  });

  final String studentId;
  final List<PaymentModel> payments;
  final List<PaymentScheduleModel> openSchedules;
  final List<PaymentTypeModel> paymentTypes;
  final Map<String, String> courseNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    // Sort open dues: overdue → oldest due date first.
    final dues = [...openSchedules]..sort((a, b) {
        int order(PaymentScheduleStatus s) {
          switch (s) {
            case PaymentScheduleStatus.overdue:
              return 0;
            case PaymentScheduleStatus.partial:
              return 1;
            case PaymentScheduleStatus.pending:
              return 2;
            default:
              return 3;
          }
        }
        final c = order(a.status).compareTo(order(b.status));
        if (c != 0) return c;
        return a.dueDate.compareTo(b.dueDate);
      });

    final totalDue = dues.fold<double>(
      0,
      (sum, s) => sum + (s.remainingAmount > 0 ? s.remainingAmount : s.amount - s.paidAmount),
    );

    Future<void> goAddPayment() async {
      await context.push<void>('/admin/payments/add', extra: studentId);
      ref.invalidate(_studentProfileProvider(studentId));
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_studentProfileProvider(studentId)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          // ── Quick add payment button ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: goAddPayment,
              icon: const Icon(Icons.add),
              label: Text('নতুন পেমেন্ট যোগ করুন', style: GoogleFonts.hindSiliguri()),
              style: FilledButton.styleFrom(backgroundColor: context.themePrimary),
            ),
          ),
          const SizedBox(height: 16),

          // ── Pending dues section ─────────────────────────────────────────
          _SectionHeader(
            title: 'বাকি পেমেন্ট',
            trailing: dues.isEmpty
                ? null
                : Text(
                    'মোট: ${fmt.format(totalDue)}',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (dues.isEmpty)
            _EmptyCard(message: 'সব পেমেন্ট আপ-টু-ডেট আছে')
          else
            ...dues.map(
              (s) => _DueTile(
                schedule: s,
                courseName: courseNames[s.courseId] ?? s.courseId,
                paymentTypeLabel: _labelForType(s.paymentTypeCode, s.paymentTypeId),
                onPay: goAddPayment,
              ),
            ),

          const SizedBox(height: 20),

          // ── Payment history section ──────────────────────────────────────
          _SectionHeader(title: 'পেমেন্ট ইতিহাস'),
          const SizedBox(height: 8),
          if (payments.isEmpty)
            _EmptyCard(message: 'কোনো পেমেন্ট নেই')
          else
            ...payments.map(
              (p) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(fmt.format(p.amount), style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${p.voucherNo} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: _StatusChip(label: p.status.toJson()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _labelForType(String code, String typeId) {
    for (final t in paymentTypes) {
      if (t.id == typeId || t.code == code) {
        return t.nameBn.isNotEmpty ? t.nameBn : t.name;
      }
    }
    return code.isEmpty ? '—' : code;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.hindSiliguri(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            style: GoogleFonts.hindSiliguri(color: Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({
    required this.schedule,
    required this.courseName,
    required this.paymentTypeLabel,
    required this.onPay,
  });

  final PaymentScheduleModel schedule;
  final String courseName;
  final String paymentTypeLabel;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final remaining = schedule.remainingAmount > 0
        ? schedule.remainingAmount
        : (schedule.amount - schedule.paidAmount);

    final monthLabel = schedule.forMonth != null
        ? DateFormat('MMM yyyy').format(schedule.forMonth!)
        : null;
    final dueLabel = DateFormat('dd MMM yyyy').format(schedule.dueDate);

    final isOverdue = schedule.status == PaymentScheduleStatus.overdue ||
        schedule.dueDate.isBefore(DateTime.now());
    final accent = isOverdue ? Colors.red.shade700 : Colors.orange.shade800;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onPay,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paymentTypeLabel,
                          style: GoogleFonts.hindSiliguri(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          courseName,
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(label: schedule.status.name, accent: accent),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (monthLabel != null) ...[
                    Icon(Icons.calendar_month_outlined,
                        size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      monthLabel,
                      style: GoogleFonts.nunito(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.event_outlined, size: 14, color: Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    'Due: $dueLabel',
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'বাকি',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          fmt.format(remaining),
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        if (schedule.paidAmount > 0)
                          Text(
                            'পরিশোধিত: ${fmt.format(schedule.paidAmount)} / ${fmt.format(schedule.amount)}',
                            style: GoogleFonts.hindSiliguri(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onPay,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.themePrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.accent});
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ResultsTab extends StatelessWidget {
  const _ResultsTab({
    required this.results,
    required this.attendanceSummary,
  });

  final List<ResultModel> results;
  final Map<String, dynamic> attendanceSummary;

  @override
  Widget build(BuildContext context) {
    final pct = attendanceSummary['percentage'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text('এই মাসের উপস্থিতি', style: GoogleFonts.hindSiliguri()),
            subtitle: Text(
              pct == null ? '—' : '${(pct as num).toStringAsFixed(1)}%',
              style: GoogleFonts.nunito(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('ফলাফল', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('কোনো ফলাফল নেই', style: GoogleFonts.hindSiliguri()),
          )
        else
          ...results.map(
            (r) => ListTile(
              title: Text(
                '${r.score.toStringAsFixed(0)} / ${r.totalMarks.toStringAsFixed(0)}',
                style: GoogleFonts.nunito(),
              ),
              subtitle: Text(
                'গ্রেড: ${r.grade ?? "—"} · র‍্যাঙ্ক: ${r.rank ?? "—"}',
                style: GoogleFonts.hindSiliguri(fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
