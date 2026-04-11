import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../doubts/repositories/doubt_repository.dart';
import '../../../admin/exams/repositories/exam_repository.dart';
import '../../../admin/attendance/repositories/attendance_repository.dart';
import '../../courses/repositories/course_repository.dart';
import '../../payments/repositories/payment_repository.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/exam_model.dart';

/// One row for "আজকের উপস্থিতি" per course.
class TodayCourseAttendanceRow {
  const TodayCourseAttendanceRow({
    required this.courseId,
    required this.courseName,
    required this.enrolledTotal,
    required this.present,
    required this.hasSession,
    required this.isCompleted,
  });

  final String courseId;
  final String courseName;
  final int enrolledTotal;
  final int present;
  final bool hasSession;
  final bool isCompleted;
}

class TodayPaymentRow {
  const TodayPaymentRow({
    required this.studentName,
    required this.amount,
    required this.paidAt,
    this.paymentLabel,
  });

  final String studentName;
  final double amount;
  final DateTime? paidAt;
  final String? paymentLabel;
}

class UpcomingExamSummary {
  const UpcomingExamSummary({
    required this.id,
    required this.title,
    required this.courseName,
    required this.examMode,
    this.startTime,
    this.examDate,
  });

  final String id;
  final String title;
  final String courseName;
  final String examMode;
  final DateTime? startTime;
  final DateTime? examDate;
}

class DoubtPreviewRow {
  const DoubtPreviewRow({
    required this.id,
    required this.studentName,
    required this.titleSnippet,
    required this.createdAt,
  });

  final String id;
  final String studentName;
  final String titleSnippet;
  final DateTime? createdAt;
}

/// Unified feed item for admin home.
class DashboardActivityItem {
  const DashboardActivityItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    this.route,
  });

  final String kind;
  final String title;
  final String subtitle;
  final DateTime at;
  final String? route;
}

/// Aggregated metrics for the admin home screen.
class AdminDashboardData {
  const AdminDashboardData({
    required this.totalStudents,
    required this.todayAttendancePct,
    required this.monthRevenue,
    required this.lastMonthRevenue,
    required this.revenueMoMPercent,
    required this.todayPaymentsCount,
    required this.upcomingExamsCount,
    required this.monthlyRevenue,
    required this.attendanceTrend,
    required this.courseDistribution,
    required this.totalDue,
    required this.openDoubtsCount,
    required this.newStudentsThisWeek,
    required this.todayCourseAttendance,
    required this.todayPayments,
    required this.upcomingExams,
    required this.doubtPreviews,
    required this.recentActivity,
    this.chartCourseId,
  });

  final int totalStudents;

  /// 0–100 or null if no sessions today.
  final double? todayAttendancePct;
  final double monthRevenue;
  final double lastMonthRevenue;

  /// null if not comparable (e.g. last month zero).
  final double? revenueMoMPercent;
  final int todayPaymentsCount;
  final int upcomingExamsCount;

  final double totalDue;
  final int openDoubtsCount;
  final int newStudentsThisWeek;

  final List<TodayCourseAttendanceRow> todayCourseAttendance;
  final List<TodayPaymentRow> todayPayments;
  final List<UpcomingExamSummary> upcomingExams;
  final List<DoubtPreviewRow> doubtPreviews;
  final List<DashboardActivityItem> recentActivity;

  /// Last 6 months revenue (same shape as [PaymentRepository.getMonthlyRevenue]).
  final List<Map<String, dynamic>> monthlyRevenue;

  /// Last N days: `label`, `pct` (0–100 or 0).
  final List<Map<String, dynamic>> attendanceTrend;

  /// Pie segments: `name`, `value` (count).
  final List<Map<String, dynamic>> courseDistribution;

  /// Selected course for chart filtering (null = all courses).
  final String? chartCourseId;
}

class DashboardRepository {
  DashboardRepository({
    SupabaseClient? client,
    PaymentRepository? paymentRepository,
    CourseRepository? courseRepository,
    ExamRepository? examRepository,
    DoubtRepository? doubtRepository,
    AttendanceRepository? attendanceRepository,
  })  : _client = client ?? supabaseClient,
        _paymentRepository = paymentRepository ?? PaymentRepository(),
        _courseRepository = courseRepository ?? CourseRepository(),
        _examRepository = examRepository ?? ExamRepository(),
        _doubtRepository = doubtRepository ?? DoubtRepository(),
        _attendanceRepository = attendanceRepository ?? AttendanceRepository();

  final SupabaseClient _client;
  final PaymentRepository _paymentRepository;
  final CourseRepository _courseRepository;
  final ExamRepository _examRepository;
  final DoubtRepository _doubtRepository;
  final AttendanceRepository _attendanceRepository;

  Future<AdminDashboardData> load({String? chartCourseId}) async {
    final cid = chartCourseId?.trim();
    final courseFilter = cid != null && cid.isNotEmpty ? cid : null;

    final monthlyRevenue = await _paymentRepository.getMonthlyRevenue(courseId: courseFilter);

    final studentsRaw = await _client
        .from(kTableUsers)
        .select('id')
        .eq('role', 'student');
    final totalStudents = (studentsRaw as List<dynamic>).length;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = monthStart;

    final monthPay = await _client
        .from(kTablePaymentLedger)
        .select('amount_paid')
        .gte('paid_at', monthStart.toUtc().toIso8601String())
        .lt('paid_at', monthEnd.toUtc().toIso8601String());
    var monthRevenue = 0.0;
    for (final e in monthPay as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final a = m['amount_paid'];
      monthRevenue += a is num ? a.toDouble() : double.tryParse('$a') ?? 0;
    }

    final lastPay = await _client
        .from(kTablePaymentLedger)
        .select('amount_paid')
        .gte('paid_at', lastMonthStart.toUtc().toIso8601String())
        .lt('paid_at', lastMonthEnd.toUtc().toIso8601String());
    var lastMonthRevenue = 0.0;
    for (final e in lastPay as List<dynamic>) {
      final m = Map<String, dynamic>.from(e as Map);
      final a = m['amount_paid'];
      lastMonthRevenue += a is num ? a.toDouble() : double.tryParse('$a') ?? 0;
    }

    double? revenueMoMPercent;
    if (lastMonthRevenue > 0) {
      revenueMoMPercent =
          ((monthRevenue - lastMonthRevenue) / lastMonthRevenue) * 100.0;
    }

    final todayStr = _sqlDate(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todayPayRows = await _client
        .from(kTablePaymentLedger)
        .select('id')
        .gte('paid_at', startOfDay.toUtc().toIso8601String())
        .lt('paid_at', endOfDay.toUtc().toIso8601String());
    final todayPaymentsCount = (todayPayRows as List<dynamic>).length;

    final todayPct = await _computeTodayAttendancePct(todayStr, courseId: courseFilter);

    final examRows = await _client
        .from(kTableExams)
        .select('id')
        .or('status.eq.scheduled,status.eq.live');
    final upcomingExamsCount = (examRows as List<dynamic>).length;

    final attendanceTrend = await _attendanceTrendLastDays(30, courseId: courseFilter);

    final courses = await _courseRepository.getCourses();
    final ids = courses.map((e) => e.id).toList();
    final counts = await _courseRepository.getEnrollmentCountsForCourses(ids);
    final courseDistribution = <Map<String, dynamic>>[];
    for (final c in courses) {
      final n = counts[c.id] ?? 0;
      if (n > 0) {
        courseDistribution.add(<String, dynamic>{'name': c.name, 'value': n.toDouble(), 'id': c.id});
      }
    }

    final totalDue = await _paymentRepository.sumOpenScheduleRemaining();

    final doubtRows = await _client.from(kTableDoubts).select('status');
    var openDoubtsCount = 0;
    for (final raw in doubtRows as List<dynamic>) {
      if ((raw as Map)['status'] == 'open') openDoubtsCount++;
    }

    final weekAgo =
        DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
    final newStud = await _client
        .from(kTableUsers)
        .select('id')
        .eq('role', 'student')
        .gte('created_at', weekAgo);
    final newStudentsThisWeek = (newStud as List<dynamic>).length;

    final todayCourseAttendance = await _buildTodayCourseRows(
      courseList: courses,
      enrollmentCounts: counts,
      date: now,
    );

    final todayPayments = await _loadTodayPayments(startOfDay, endOfDay);
    final upcomingExams = await _loadUpcomingExams();
    final doubtPreviews = await _loadDoubtPreviews();
    final recentActivity = await _loadRecentActivity();

    return AdminDashboardData(
      totalStudents: totalStudents,
      todayAttendancePct: todayPct,
      monthRevenue: monthRevenue,
      lastMonthRevenue: lastMonthRevenue,
      revenueMoMPercent: revenueMoMPercent,
      todayPaymentsCount: todayPaymentsCount,
      upcomingExamsCount: upcomingExamsCount,
      monthlyRevenue: monthlyRevenue,
      attendanceTrend: attendanceTrend,
      courseDistribution: courseDistribution,
      totalDue: totalDue,
      openDoubtsCount: openDoubtsCount,
      newStudentsThisWeek: newStudentsThisWeek,
      todayCourseAttendance: todayCourseAttendance,
      todayPayments: todayPayments,
      upcomingExams: upcomingExams,
      doubtPreviews: doubtPreviews,
      recentActivity: recentActivity,
      chartCourseId: courseFilter,
    );
  }

  Future<List<TodayCourseAttendanceRow>> _buildTodayCourseRows({
    required List<CourseModel> courseList,
    required Map<String, int> enrollmentCounts,
    required DateTime date,
  }) async {
    final ids = courseList.map((e) => e.id).toList();
    if (ids.isEmpty) return [];
    final summaries = await _attendanceRepository.getCourseSessionsForDate(
      courseIds: ids,
      date: date,
    );
    final out = <TodayCourseAttendanceRow>[];
    for (final c in courseList) {
      final en = enrollmentCounts[c.id] ?? 0;
      final s = summaries[c.id];
      final has = s != null && s.sessionId.isNotEmpty;
        final present = has ? s.presentCount : 0;
      out.add(
        TodayCourseAttendanceRow(
          courseId: c.id,
          courseName: c.name,
          enrolledTotal: en,
          present: present,
          hasSession: has,
          isCompleted: s?.isCompleted ?? false,
        ),
      );
    }
    return out;
  }

  Future<List<TodayPaymentRow>> _loadTodayPayments(
    DateTime startOfDay,
    DateTime endOfDay,
  ) async {
    final rows = await _client
        .from(kTablePaymentLedger)
        .select('amount_paid, paid_at, payment_type_code, student_id')
        .gte('paid_at', startOfDay.toUtc().toIso8601String())
        .lt('paid_at', endOfDay.toUtc().toIso8601String())
        .order('paid_at', ascending: false)
        .limit(8);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return [];
    final studentIds = list
        .map((e) => Map<String, dynamic>.from(e as Map)['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final names = <String, String>{};
    if (studentIds.isNotEmpty) {
      final urows =
          await _client.from(kTableUsers).select('id, full_name_bn').inFilter('id', studentIds);
      for (final raw in urows as List<dynamic>) {
        final m = Map<String, dynamic>.from(raw as Map);
        names[m['id'] as String] = m['full_name_bn'] as String? ?? '—';
      }
    }
    return list.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String? ?? '';
      return TodayPaymentRow(
        studentName: names[sid] ?? sid,
        amount: _parseAmount(m['amount_paid']),
        paidAt: DateTime.tryParse(m['paid_at']?.toString() ?? '')?.toLocal(),
        paymentLabel: m['payment_type_code']?.toString(),
      );
    }).toList();
  }

  Future<List<UpcomingExamSummary>> _loadUpcomingExams() async {
    final exams = await _examRepository.listExams();
    final courseList = await _courseRepository.getCourses();
    final courseNames = {for (final c in courseList) c.id: c.name};
    final filtered = exams.where((ExamModel e) {
      return e.status == 'scheduled' || e.status == 'live';
    }).toList();
    filtered.sort((a, b) {
      final da = a.startTime ?? a.examDate ?? DateTime(2100);
      final db = b.startTime ?? b.examDate ?? DateTime(2100);
      return da.compareTo(db);
    });
    return filtered.take(8).map((e) {
      return UpcomingExamSummary(
        id: e.id,
        title: e.title,
        courseName: courseNames[e.courseId] ?? e.courseId,
        examMode: e.examMode,
        startTime: e.startTime,
        examDate: e.examDate,
      );
    }).toList();
  }

  Future<List<DoubtPreviewRow>> _loadDoubtPreviews() async {
    final rows = await _client
        .from(kTableDoubts)
        .select('id, student_id, title, created_at')
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(4);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return [];
    final ids = list
        .map((e) => Map<String, dynamic>.from(e as Map)['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final users = await _doubtRepository.loadUsersByIds(ids);
    return list.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String? ?? '';
      final u = users[sid];
      final title = m['title']?.toString() ?? '';
      return DoubtPreviewRow(
        id: m['id'] as String? ?? '',
        studentName: u?.fullNameBn ?? '—',
        titleSnippet: title.length > 42 ? '${title.substring(0, 42)}…' : title,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<List<DashboardActivityItem>> _loadRecentActivity() async {
    final items = <DashboardActivityItem>[];

    final payRows = await _client
        .from(kTablePaymentLedger)
        .select('amount_paid, paid_at, student_id, payment_type_code')
        .order('paid_at', ascending: false)
        .limit(6);
    final pList = payRows as List<dynamic>;
    final pStudentIds = pList
        .map((e) => Map<String, dynamic>.from(e as Map)['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final pNames = <String, String>{};
    if (pStudentIds.isNotEmpty) {
      final urows =
          await _client.from(kTableUsers).select('id, full_name_bn').inFilter('id', pStudentIds);
      for (final raw in urows as List<dynamic>) {
        final m = Map<String, dynamic>.from(raw as Map);
        pNames[m['id'] as String] = m['full_name_bn'] as String? ?? '—';
      }
    }
    for (final raw in pList) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String? ?? '';
      final at = DateTime.tryParse(m['paid_at']?.toString() ?? '');
      if (at == null) continue;
      final amt = _parseAmount(m['amount_paid']);
      items.add(
        DashboardActivityItem(
          kind: 'payment',
          title: pNames[sid] ?? sid,
          subtitle:
              '৳ ${amt.toStringAsFixed(0)} · ${m['payment_type_code'] ?? ''}',
          at: at.toLocal(),
          route: '/admin/payments',
        ),
      );
    }

    final studRows = await _client
        .from(kTableUsers)
        .select('id, full_name_bn, created_at')
        .eq('role', 'student')
        .order('created_at', ascending: false)
        .limit(4);
    for (final raw in studRows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final at = DateTime.tryParse(m['created_at']?.toString() ?? '');
      if (at == null) continue;
      items.add(
        DashboardActivityItem(
          kind: 'student',
          title: m['full_name_bn']?.toString() ?? 'শিক্ষার্থী',
          subtitle: 'নতুন নিবন্ধন',
          at: at.toLocal(),
          route: '/admin/students/${m['id']}',
        ),
      );
    }

    final doubtRows = await _client
        .from(kTableDoubts)
        .select('id, student_id, title, created_at')
        .order('created_at', ascending: false)
        .limit(4);
    final dList = doubtRows as List<dynamic>;
    final dIds = dList
        .map((e) => Map<String, dynamic>.from(e as Map)['student_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final dNames = await _doubtRepository.loadUsersByIds(dIds);
    for (final raw in dList) {
      final m = Map<String, dynamic>.from(raw as Map);
      final at = DateTime.tryParse(m['created_at']?.toString() ?? '');
      if (at == null) continue;
      final sid = m['student_id'] as String? ?? '';
      items.add(
        DashboardActivityItem(
          kind: 'doubt',
          title: dNames[sid]?.fullNameBn ?? '—',
          subtitle: m['title']?.toString() ?? 'Doubt',
          at: at.toLocal(),
          route: '/admin/doubts/${m['id']}',
        ),
      );
    }

    final examRows = await _client
        .from(kTableExams)
        .select('id, title, updated_at, status')
        .order('updated_at', ascending: false)
        .limit(3);
    for (final raw in examRows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final at = DateTime.tryParse(m['updated_at']?.toString() ?? '');
      if (at == null) continue;
      items.add(
        DashboardActivityItem(
          kind: 'exam',
          title: m['title']?.toString() ?? 'পরীক্ষা',
          subtitle: m['status']?.toString() ?? '',
          at: at.toLocal(),
          route: '/admin/exams',
        ),
      );
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(15).toList();
  }

  Future<double?> _computeTodayAttendancePct(String dateStr, {String? courseId}) async {
    var q = _client.from(kTableAttendanceSessions).select('id').eq('date', dateStr);
    if (courseId != null && courseId.isNotEmpty) {
      q = q.eq('course_id', courseId);
    }
    final sessions = await q;
    final sessionIds = (sessions as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['id'] as String)
        .toList();
    if (sessionIds.isEmpty) return null;

    var present = 0;
    var total = 0;
    for (final sid in sessionIds) {
      final recs = await _client
          .from(kTableAttendanceRecords)
          .select('status')
          .eq('session_id', sid);
      for (final r in recs as List<dynamic>) {
        final st = Map<String, dynamic>.from(r as Map)['status'] as String?;
        total++;
        if (st == 'present' || st == 'late') present++;
      }
    }
    if (total == 0) return null;
    return (present * 100.0) / total;
  }

  Future<List<Map<String, dynamic>>> _attendanceTrendLastDays(int days, {String? courseId}) async {
    final out = <Map<String, dynamic>>[];
    final today = DateTime.now();
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final ds = _sqlDate(d);
      final pct = await _computeTodayAttendancePct(ds, courseId: courseId);
      out.add(<String, dynamic>{
        'label': '${d.day}/${d.month}',
        'pct': pct ?? 0.0,
      });
    }
    return out;
  }

  static String _sqlDate(DateTime d) {
    final u = DateTime.utc(d.year, d.month, d.day);
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
