import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/models/enrollment_model.dart' show EnrollmentStatus;
import '../../../shared/models/exam_model.dart';
import '../../../shared/models/doubt_thread_model.dart';
import '../../../shared/models/payment_schedule_model.dart';
import '../../../shared/models/user_model.dart';
import '../../admin/courses/repositories/course_repository.dart';
import '../../admin/payments/repositories/payment_repository.dart';
import '../../admin/students/repositories/student_repository.dart';
import '../../doubts/repositories/doubt_repository.dart';
import '../../results/repositories/result_repository.dart';
import '../exams/repositories/student_exam_repository.dart';
import '../notes/repositories/notes_repository.dart';
class LatestResultSummary {
  const LatestResultSummary({
    required this.examTitle,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    this.rank,
    this.grade,
  });

  final String examTitle;
  final double score;
  final double totalMarks;
  final double percentage;
  final int? rank;
  final String? grade;
}

class EnrolledCourseCardData {
  const EnrolledCourseCardData({
    required this.course,
    required this.notesProgressPct,
  });

  final CourseModel course;
  final double notesProgressPct;
}

enum StudentDashboardAlertKind { paymentDue, attendanceLow, doubtActive }

class StudentDashboardAlert {
  const StudentDashboardAlert({
    required this.kind,
    required this.message,
    required this.actionLabel,
    required this.route,
  });

  final StudentDashboardAlertKind kind;
  final String message;
  final String actionLabel;
  final String route;
}

class StudentActivityItem {
  const StudentActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String route;
}

class StudentDashboardData {
  const StudentDashboardData({
    required this.student,
    required this.attendancePct,
    required this.attendancePresent,
    required this.attendanceTotal,
    required this.latestResult,
    required this.openDuesCount,
    required this.openDueTotal,
    required this.paymentMonthLabel,
    required this.paymentOk,
    required this.openDoubts,
    required this.inProgressDoubts,
    required this.solvedDoubtsCount,
    required this.upcomingExams,
    required this.enrolledCourses,
    required this.alerts,
    required this.dailySuggestion,
    required this.recentActivity,
    this.lastLectureTitle,
    this.lastLectureChapterId,
  });

  final UserModel student;
  final double? attendancePct;
  final int attendancePresent;
  final int attendanceTotal;
  final LatestResultSummary? latestResult;
  final int openDuesCount;
  final double openDueTotal;
  final String paymentMonthLabel;
  final bool paymentOk;
  final int openDoubts;
  final int inProgressDoubts;
  final int solvedDoubtsCount;
  final List<ExamModel> upcomingExams;
  final List<EnrolledCourseCardData> enrolledCourses;
  final List<StudentDashboardAlert> alerts;
  final String dailySuggestion;
  final List<StudentActivityItem> recentActivity;
  final String? lastLectureTitle;
  final String? lastLectureChapterId;
}

final studentDashboardProvider =
    FutureProvider.autoDispose<StudentDashboardData>((ref) async {
  final uid = supabaseClient.auth.currentUser!.id;
  final month = DateTime.now();
  final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';

  final studentRepo = StudentRepository();
  final paymentRepo = PaymentRepository();
  final doubtRepo = DoubtRepository();
  final examRepo = StudentExamRepository();
  final resultRepo = ResultRepository();
  final notesRepo = NotesRepository();
  final courseRepo = CourseRepository();

  final student = await studentRepo.getStudentById(uid);
  final att = await studentRepo.getStudentAttendanceSummary(uid, ym);
  final attendancePct = att['percentage'] as double?;
  final attendancePresent = (att['present'] as num?)?.toInt() ?? 0;
  final attendanceTotal = (att['total_sessions'] as num?)?.toInt() ?? 0;

  final dues = await paymentRepo.getPaymentSchedule(studentId: uid, onlyOpen: true);
  final openDues =
      dues.where((d) => d.status != PaymentScheduleStatus.paid).toList();
  final openDueTotal = openDues.fold<double>(
    0,
    (a, d) => a + (d.remainingAmount > 0 ? d.remainingAmount : d.amount),
  );

  final paymentMonthLabel =
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
  final paymentOk = openDues.isEmpty;

  final results = await resultRepo.getStudentResults(studentId: uid);
  LatestResultSummary? latestResult;
  if (results.isNotEmpty) {
    final r = results.first;
    final exam = Map<String, dynamic>.from(r['exams'] as Map? ?? const {});
    latestResult = LatestResultSummary(
      examTitle: exam['title']?.toString() ?? 'পরীক্ষা',
      score: (r['score'] as num?)?.toDouble() ?? 0,
      totalMarks: (r['total_marks'] as num?)?.toDouble() ?? 0,
      percentage: (r['percentage'] as num?)?.toDouble() ?? 0,
      rank: (r['rank'] as num?)?.toInt(),
      grade: r['grade']?.toString(),
    );
  }

  final myDoubts = await doubtRepo.listMyDoubts();
  var openDoubts = 0;
  var inProgressDoubts = 0;
  for (final d in myDoubts) {
    if (d.status == DoubtStatus.open) openDoubts++;
    if (d.status == DoubtStatus.inProgress) inProgressDoubts++;
  }
  var solvedDoubts = 0;
  try {
    solvedDoubts = await doubtRepo.countSolvedForStudent(uid);
  } catch (_) {}

  final allExams = await examRepo.listExamsForCurrentStudent();
  final now = DateTime.now();
  final upcoming = allExams.where((e) {
    if (e.status != 'scheduled' && e.status != 'live') return false;
    final t = e.startTime ?? e.examDate;
    if (t == null) return true;
    return t.isAfter(now.subtract(const Duration(minutes: 1)));
  }).toList();
  upcoming.sort((a, b) {
    final da = a.startTime ?? a.examDate ?? DateTime(2100);
    final db = b.startTime ?? b.examDate ?? DateTime(2100);
    return da.compareTo(db);
  });

  final enrollments = await studentRepo.getMyEnrollments();
  final enrolledCourses = <EnrolledCourseCardData>[];
  for (final e in enrollments) {
    if (e.status != EnrollmentStatus.active) continue;
    try {
      final c = await courseRepo.getCourseById(e.courseId);
      final pct = await notesRepo.getNotesProgressPercentForCourse(c.id);
      enrolledCourses.add(EnrolledCourseCardData(course: c, notesProgressPct: pct));
    } catch (_) {}
  }

  final lastLecture = await notesRepo.getLatestLectureForCurrentStudent();

  final alerts = <StudentDashboardAlert>[];
  if (openDues.isNotEmpty) {
    final d = openDues.first;
    alerts.add(
      StudentDashboardAlert(
        kind: StudentDashboardAlertKind.paymentDue,
        message:
            'বকেয়া ৳ ${d.remainingAmount > 0 ? d.remainingAmount.toStringAsFixed(0) : d.amount.toStringAsFixed(0)} · Due ${d.dueDate.day}/${d.dueDate.month}',
        actionLabel: 'বিস্তারিত →',
        route: '/student/payments',
      ),
    );
  }
  if (attendancePct != null && attendancePct < 75) {
    alerts.add(
      StudentDashboardAlert(
        kind: StudentDashboardAlertKind.attendanceLow,
        message:
            'তোমার উপস্থিতি ${attendancePct.toStringAsFixed(0)}% — ৭৫%-এর নিচে।',
        actionLabel: 'দেখুন →',
        route: '/student/attendance',
      ),
    );
  }
  if (inProgressDoubts > 0) {
    alerts.add(
      StudentDashboardAlert(
        kind: StudentDashboardAlertKind.doubtActive,
        message: '$inProgressDoubts টি doubt-এ স্টাফের উত্তরের অপেক্ষায়।',
        actionLabel: 'দেখুন →',
        route: '/student/doubts',
      ),
    );
  }

  const tips = <String>[
    'MCQ পরীক্ষায় আগে সহজ প্রশ্নগুলো দাও, তারপর কঠিনগুলোতে সময় দাও।',
    'সন্দেহ হলে ছেড়ে দাও — নেগেটিভ মার্কিং তোমার বিপদ করতে পারে।',
    'প্রতিদিন একটু করে পড়লে বড় সিলেবাসও শেষ হয়।',
    'গুরুত্বপূর্ণ অধ্যায়ে আগে নোট দেখে নাও।',
    'পরীক্ষার আগের রাতে নতুন না পড়ে পুরনো টা রিভিশন করো।',
    'সময় দেখে ক্লাসে এসো — উপস্থিতি ফলে প্রভাব ফেলে।',
    'প্রশ্ন ব্যাংকে দুর্বল ক্যাপ্টার থেকে বেশি অনুশীলন করো।',
    'ফলাফল পেলে ভুলগুলো লেখে রাখো — পরের বার কাজে লাগবে।',
  ];
  final dailySuggestion = tips[DateTime.now().day % tips.length];

  final recentActivity = <StudentActivityItem>[];
  final payments = await paymentRepo.getPaymentLedger(studentId: uid);
  for (final p in payments.take(3)) {
    recentActivity.add(
      StudentActivityItem(
        icon: '💳',
        title: 'পেমেন্ট',
        subtitle:
            '৳ ${p.amountPaid.toStringAsFixed(0)} · ${p.paymentTypeCode}',
        route: '/student/payments',
      ),
    );
  }
  if (lastLecture != null) {
    recentActivity.add(
      StudentActivityItem(
        icon: '📄',
        title: lastLecture['title']?.toString() ?? 'নোট',
        subtitle: 'নতুন লেকচার',
        route:
            '/student/notes/${lastLecture['chapter_id']}',
      ),
    );
  }
  if (results.isNotEmpty) {
    final r = results.first;
    final exam = Map<String, dynamic>.from(r['exams'] as Map? ?? const {});
    recentActivity.add(
      StudentActivityItem(
        icon: '📊',
        title: exam['title']?.toString() ?? 'ফলাফল',
        subtitle:
            '${r['percentage']}% · Rank ${r['rank'] ?? '-'}',
        route: '/student/results',
      ),
    );
  }

  return StudentDashboardData(
    student: student,
    attendancePct: attendancePct,
    attendancePresent: attendancePresent,
    attendanceTotal: attendanceTotal,
    latestResult: latestResult,
    openDuesCount: openDues.length,
    openDueTotal: openDueTotal,
    paymentMonthLabel: paymentMonthLabel,
    paymentOk: paymentOk,
    openDoubts: openDoubts,
    inProgressDoubts: inProgressDoubts,
    solvedDoubtsCount: solvedDoubts,
    upcomingExams: upcoming.take(6).toList(),
    enrolledCourses: enrolledCourses,
    alerts: alerts,
    dailySuggestion: dailySuggestion,
    recentActivity: recentActivity.take(8).toList(),
    lastLectureTitle: lastLecture?['title'] as String?,
    lastLectureChapterId: lastLecture?['chapter_id'] as String?,
  );
});
