import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme.dart';
import '../../courses/providers/courses_provider.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/attendance_providers.dart';
import '../repositories/attendance_repository.dart';

class AttendanceReportsScreen extends ConsumerStatefulWidget {
  const AttendanceReportsScreen({
    super.key,
    required this.courseId,
    this.sessionId,
  });

  final String courseId;
  final String? sessionId;

  @override
  ConsumerState<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends ConsumerState<AttendanceReportsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late final String _courseId = widget.courseId;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(attendanceRepositoryProvider);
    final courseFuture = ref.read(courseRepositoryProvider).getCourseById(_courseId);
    final monthFuture = repo.getCourseMonthlySummary(courseId: _courseId, month: _month);
    final trendFuture = repo.getAttendanceTrend30Days(_courseId);
    final dailyFuture = _sessionId == null ? null : repo.getDailyReportBySession(_sessionId!);

    return AdminResponsiveScaffold(
      title: Text('Attendance Reports', style: GoogleFonts.hindSiliguri()),
      body: FutureBuilder(
        future: courseFuture,
        builder: (context, courseSnap) {
          final courseName = courseSnap.data?.name ?? 'কোর্স';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      courseName,
                      style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat.yMMMM().format(_month), style: GoogleFonts.hindSiliguri()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (dailyFuture != null)
                FutureBuilder<AttendanceDailyReport>(
                  future: dailyFuture,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    final r = snap.data!;
                    return _DailyCard(report: r, onShare: () => _shareDaily(r, courseName));
                  },
                ),
              const SizedBox(height: 12),
              FutureBuilder<List<AttendanceMonthlyStudentSummary>>(
                future: monthFuture,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final rows = snap.data!;
                  final warning = rows.where((e) => e.percentage < 75).toList();
                  return Column(
                    children: [
                      _MonthlyCard(
                        rows: rows,
                        onShare: () => _shareMonthly(rows, courseName),
                      ),
                      const SizedBox(height: 12),
                      _WarningCard(
                        rows: warning,
                        onShare: () => _shareWarning(warning, courseName),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: trendFuture,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  return _TrendCard(points: snap.data!);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'রিপোর্ট মাস',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month, 1));
  }

  Future<void> _shareDaily(AttendanceDailyReport r, String courseName) async {
    final b = StringBuffer();
    b.writeln('উপস্থিতি রিপোর্ট');
    b.writeln('কোর্স: $courseName');
    b.writeln('তারিখ: ${DateFormat('yyyy-MM-dd').format(r.date)}');
    b.writeln('মোট: ${r.totalStudents}, উপস্থিত: ${r.presentCount}, অনুপস্থিত: ${r.absentCount}');
    b.writeln('\nঅনুপস্থিত শিক্ষার্থী:');
    for (final s in r.absentStudents) {
      b.writeln('- ${s.studentNameBn} (${s.studentCode ?? "—"})');
    }
    await SharePlus.instance.share(ShareParams(text: b.toString(), subject: 'daily_attendance'));
  }

  Future<void> _shareMonthly(List<AttendanceMonthlyStudentSummary> rows, String courseName) async {
    final b = StringBuffer();
    b.writeln('course,student,student_code,total,present,absent,percentage');
    for (final e in rows) {
      b.writeln(
        '"$courseName","${e.studentNameBn}","${e.studentCode ?? ''}",${e.totalClasses},${e.present},${e.absent},${e.percentage.toStringAsFixed(1)}',
      );
    }
    await SharePlus.instance.share(ShareParams(text: b.toString(), subject: 'monthly_attendance_summary'));
  }

  Future<void> _shareWarning(List<AttendanceMonthlyStudentSummary> rows, String courseName) async {
    final b = StringBuffer();
    b.writeln('কম উপস্থিতি (<75%) তালিকা - $courseName');
    for (final e in rows) {
      b.writeln('${e.studentNameBn} (${e.studentCode ?? "—"}) - ${e.percentage.toStringAsFixed(1)}%');
    }
    await SharePlus.instance.share(ShareParams(text: b.toString(), subject: 'attendance_warning_list'));
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.report, required this.onShare});
  final AttendanceDailyReport report;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final pct = report.totalStudents == 0 ? 0.0 : (report.presentCount * 100.0) / report.totalStudents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Daily Report', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold))),
                IconButton(onPressed: onShare, icon: const Icon(Icons.ios_share_outlined)),
              ],
            ),
            Text(
              'মোট ${report.totalStudents} | উপস্থিত ${report.presentCount} | অনুপস্থিত ${report.absentCount} | ${pct.toStringAsFixed(1)}%',
              style: GoogleFonts.hindSiliguri(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({required this.rows, required this.onShare});
  final List<AttendanceMonthlyStudentSummary> rows;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Course Monthly Summary', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold))),
                IconButton(onPressed: onShare, icon: const Icon(Icons.ios_share_outlined)),
              ],
            ),
            ...rows.take(30).map(
              (e) => ListTile(
                dense: true,
                title: Text(e.studentNameBn, style: GoogleFonts.hindSiliguri()),
                subtitle: Text('মোট ${e.totalClasses} | উপস্থিত ${e.present} | অনুপস্থিত ${e.absent}', style: GoogleFonts.hindSiliguri(fontSize: 12)),
                trailing: Text('${e.percentage.toStringAsFixed(1)}%', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.rows, required this.onShare});
  final List<AttendanceMonthlyStudentSummary> rows;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('<75% Warning List', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold))),
                IconButton(onPressed: onShare, icon: const Icon(Icons.ios_share_outlined)),
              ],
            ),
            if (rows.isEmpty)
              Text('চমৎকার! কোনো সতর্কতা নেই।', style: GoogleFonts.hindSiliguri())
            else
              ...rows.map(
                (e) => ListTile(
                  dense: true,
                  title: Text(e.studentNameBn, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(e.studentCode ?? '—', style: GoogleFonts.nunito(fontSize: 12)),
                  trailing: Text('${e.percentage.toStringAsFixed(1)}%', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});
  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final y = (points[i]['percentage'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), y));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance Trend (30 days)', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: spots.isEmpty
                  ? Center(child: Text('ডাটা নেই', style: GoogleFonts.hindSiliguri()))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3,
                            color: AppTheme.accent,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: true),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
