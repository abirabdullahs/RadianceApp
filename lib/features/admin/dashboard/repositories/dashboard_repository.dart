import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../courses/repositories/course_repository.dart';
import '../../payments/repositories/payment_repository.dart';

/// Aggregated metrics for the admin home screen.
class AdminDashboardData {
  const AdminDashboardData({
    required this.totalStudents,
    required this.todayAttendancePct,
    required this.monthRevenue,
    required this.todayPaymentsCount,
    required this.upcomingExamsCount,
    required this.monthlyRevenue,
    required this.attendanceTrend,
    required this.courseDistribution,
  });

  final int totalStudents;

  /// 0–100 or null if no sessions today.
  final double? todayAttendancePct;
  final double monthRevenue;
  final int todayPaymentsCount;
  final int upcomingExamsCount;

  /// Last 6 months revenue (same shape as [PaymentRepository.getMonthlyRevenue]).
  final List<Map<String, dynamic>> monthlyRevenue;

  /// Last 7 days: `label`, `pct` (0–100 or 0).
  final List<Map<String, dynamic>> attendanceTrend;

  /// Pie segments: `name`, `value` (count).
  final List<Map<String, dynamic>> courseDistribution;
}

class DashboardRepository {
  DashboardRepository({
    SupabaseClient? client,
    PaymentRepository? paymentRepository,
    CourseRepository? courseRepository,
  })  : _client = client ?? supabaseClient,
        _paymentRepository = paymentRepository ?? PaymentRepository(),
        _courseRepository = courseRepository ?? CourseRepository();

  final SupabaseClient _client;
  final PaymentRepository _paymentRepository;
  final CourseRepository _courseRepository;

  Future<AdminDashboardData> load() async {
    final monthlyRevenue = await _paymentRepository.getMonthlyRevenue();

    final studentsRaw = await _client
        .from(kTableUsers)
        .select('id')
        .eq('role', 'student');
    final totalStudents = (studentsRaw as List<dynamic>).length;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

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

    final todayStr = _sqlDate(now);
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todayPayRows = await _client
        .from(kTablePaymentLedger)
        .select('id')
        .gte('paid_at', startOfDay.toUtc().toIso8601String())
        .lt('paid_at', endOfDay.toUtc().toIso8601String());
    final todayPaymentsCount = (todayPayRows as List<dynamic>).length;

    final todayPct = await _computeTodayAttendancePct(todayStr);

    final examRows = await _client
        .from(kTableExams)
        .select('id')
        .or('status.eq.scheduled,status.eq.live');
    final upcomingExamsCount = (examRows as List<dynamic>).length;

    final attendanceTrend = await _attendanceTrendLastDays(7);

    final courses = await _courseRepository.getCourses();
    final ids = courses.map((e) => e.id).toList();
    final counts = await _courseRepository.getEnrollmentCountsForCourses(ids);
    final courseDistribution = <Map<String, dynamic>>[];
    for (final c in courses) {
      final n = counts[c.id] ?? 0;
      if (n > 0) {
        courseDistribution.add(<String, dynamic>{'name': c.name, 'value': n.toDouble()});
      }
    }

    return AdminDashboardData(
      totalStudents: totalStudents,
      todayAttendancePct: todayPct,
      monthRevenue: monthRevenue,
      todayPaymentsCount: todayPaymentsCount,
      upcomingExamsCount: upcomingExamsCount,
      monthlyRevenue: monthlyRevenue,
      attendanceTrend: attendanceTrend,
      courseDistribution: courseDistribution,
    );
  }

  Future<double?> _computeTodayAttendancePct(String dateStr) async {
    final sessions = await _client
        .from(kTableAttendanceSessions)
        .select('id')
        .eq('date', dateStr);
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

  Future<List<Map<String, dynamic>>> _attendanceTrendLastDays(int days) async {
    final out = <Map<String, dynamic>>[];
    final today = DateTime.now();
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final ds = _sqlDate(d);
      final pct = await _computeTodayAttendancePct(ds);
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
}
