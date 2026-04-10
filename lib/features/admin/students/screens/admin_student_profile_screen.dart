import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/result_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/repositories/course_repository.dart';
import '../repositories/student_repository.dart';

final _studentProfileProvider =
    FutureProvider.autoDispose.family<_StudentProfileBundle, String>((ref, id) async {
  final repo = StudentRepository();
  final courseRepo = CourseRepository();
  final student = await repo.getStudentById(id);
  final enrollments = await repo.getStudentEnrollments(id);
  final payments = await repo.getStudentPayments(id);
  final results = await repo.getStudentResults(id);
  final month = DateTime.now();
  final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  final att = await repo.getStudentAttendanceSummary(id, ym);
  final courseNames = <String, String>{};
  for (final e in enrollments) {
    try {
      final c = await courseRepo.getCourseById(e.courseId);
      courseNames[e.courseId] = c.name;
    } catch (_) {
      courseNames[e.courseId] = e.courseId;
    }
  }
  return _StudentProfileBundle(
    student: student,
    enrollments: enrollments,
    courseNames: courseNames,
    payments: payments,
    results: results,
    attendanceSummary: att,
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
  });

  final UserModel student;
  final List<EnrollmentModel> enrollments;
  final Map<String, String> courseNames;
  final List<PaymentModel> payments;
  final List<ResultModel> results;
  final Map<String, dynamic> attendanceSummary;
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
                _PaymentsTab(payments: b.payments),
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

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.payments});

  final List<PaymentModel> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(child: Text('কোনো পেমেন্ট নেই', style: GoogleFonts.hindSiliguri()));
    }
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i];
        return ListTile(
          title: Text(fmt.format(p.amount), style: GoogleFonts.nunito()),
          subtitle: Text(
            '${p.voucherNo} · ${DateFormat.yMMMd().format(p.paidAt ?? DateTime.now())}',
            style: GoogleFonts.nunito(fontSize: 12),
          ),
        );
      },
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
