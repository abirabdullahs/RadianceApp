import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/i18n/app_localizations.dart';
import '../../../core/supabase_client.dart';
import '../../admin/students/repositories/student_repository.dart';
import '../widgets/student_drawer.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  late Future<_AttendanceVm> _future;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _courseId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AttendanceVm> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final repo = StudentRepository();
    final courses = await repo.getStudentAttendanceCourses(uid);
    if (courses.isEmpty) {
      return _AttendanceVm(
        courses: const [],
        selectedCourseId: '',
        month: _month,
        data: const <String, dynamic>{},
      );
    }
    final selected = _courseId ?? courses.first['id']!;
    final data = await repo.getStudentCourseAttendanceMonthly(
      studentId: uid,
      courseId: selected,
      month: _month,
    );
    return _AttendanceVm(
      courses: courses,
      selectedCourseId: selected,
      month: _month,
      data: data,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
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
        title: Text(l10n.t('attendance'), style: GoogleFonts.hindSiliguri()),
        actions: const [AppBarDrawerAction()],
      ),
      body: FutureBuilder<_AttendanceVm>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${l10n.t('load_failed')}: ${snap.error}',
                  style: GoogleFonts.hindSiliguri(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final vm = snap.data!;
          if (vm.courses.isEmpty) {
            return Center(
              child: Text(l10n.t('att_not_enrolled'), style: GoogleFonts.hindSiliguri()),
            );
          }

          final m = vm.data;
          final pct = m['percentage'] as double?;
          final total = m['total_sessions'] as int? ?? 0;
          final present = m['present'] as int? ?? 0;
          final absent = m['absent'] as int? ?? 0;
          final calendar = (m['calendar'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ) ??
              const <String, String>{};
          final monthLabel = DateFormat.yMMMM().format(_month);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: vm.selectedCourseId,
                        decoration: InputDecoration(
                          labelText: l10n.t('courses'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: vm.courses
                            .map(
                              (c) => DropdownMenuItem(
                                value: c['id'],
                                child: Text(
                                  c['name'] ?? l10n.t('course_fallback_name'),
                                  style: GoogleFonts.hindSiliguri(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _courseId = v;
                          _reload();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _month = DateTime(_month.year, _month.month - 1, 1);
                        _reload();
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          monthLabel,
                          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _month = DateTime(_month.year, _month.month + 1, 1);
                        _reload();
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _statCard(l10n.t('att_total_classes'), '$total')),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard(l10n.t('att_present_label'), '$present')),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard(l10n.t('att_absent_label'), '$absent')),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pct == null
                              ? '${l10n.t('att_rate')}: —'
                              : '${l10n.t('att_rate')}: ${pct.toStringAsFixed(1)}%',
                          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: pct == null ? 0 : (pct / 100.0).clamp(0.0, 1.0),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (pct ?? 0) < 75 ? l10n.t('att_warn_below_75') : l10n.t('att_status_good'),
                          style: GoogleFonts.hindSiliguri(
                            color: (pct ?? 0) < 75 ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AttendanceCalendar(month: _month, statusByDate: calendar, l10n: l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.hindSiliguri(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceVm {
  const _AttendanceVm({
    required this.courses,
    required this.selectedCourseId,
    required this.month,
    required this.data,
  });
  final List<Map<String, String>> courses;
  final String selectedCourseId;
  final DateTime month;
  final Map<String, dynamic> data;
}

class _AttendanceCalendar extends StatelessWidget {
  const _AttendanceCalendar({
    required this.month,
    required this.statusByDate,
    required this.l10n,
  });

  final DateTime month;
  final Map<String, String> statusByDate;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7; // sun=0
    final cells = <Widget>[];

    final labels = [
      l10n.t('weekday_sun'),
      l10n.t('weekday_mon'),
      l10n.t('weekday_tue'),
      l10n.t('weekday_wed'),
      l10n.t('weekday_thu'),
      l10n.t('weekday_fri'),
      l10n.t('weekday_sat'),
    ];
    for (final l in labels) {
      cells.add(Center(child: Text(l, style: GoogleFonts.hindSiliguri(fontSize: 11, fontWeight: FontWeight.w600))));
    }
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final key = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final st = statusByDate[key];
      final text = st == 'present' || st == 'late' ? '✅' : st == 'absent' ? '❌' : '⚪';
      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('$day\n$text', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 11)),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('att_calendar_title'), style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
            const SizedBox(height: 8),
            Text(l10n.t('att_legend'), style: GoogleFonts.hindSiliguri(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
