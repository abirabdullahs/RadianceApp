import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/attendance_providers.dart';
import '../repositories/attendance_repository.dart';

/// Attendance home (today overview + start attendance form).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _courseId;
  DateTime _date = DateTime.now();
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return AdminResponsiveScaffold(
      title: Text('উপস্থিতি', style: GoogleFonts.hindSiliguri()),
      body: coursesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('প্রথমে একটি কোর্স যোগ করুন', style: GoogleFonts.hindSiliguri()),
            );
          }
          final selectedId = _courseId ?? items.first.course.id;
          final courseIds = items.map((e) => e.course.id).toList();

          return FutureBuilder(
            future: ref.read(attendanceRepositoryProvider).getCourseSessionsForDate(
                  courseIds: courseIds,
                  date: DateTime.now(),
                ),
            builder: (context, snapshot) {
              final map = snapshot.data ?? const <String, AttendanceCourseSessionSummary>{};
              final daily = _buildDailySummary(items, map);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TodayHeader(date: DateTime.now()),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.push('/admin/attendance/settings'),
                      icon: const Icon(Icons.settings),
                      label: Text('সেটিংস', style: GoogleFonts.hindSiliguri()),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SummaryTiles(data: daily),
                  const SizedBox(height: 20),
                  Text(
                    'আজকের ক্লাস',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final it in items) ...[
                    _TodayCourseCard(
                      item: it,
                      summary: map[it.course.id],
                      onOpen: () => _openTaking(it.course.id, DateTime.now()),
                      onReport: () => context.push('/admin/attendance/reports/${it.course.id}${map[it.course.id]?.sessionId.isNotEmpty == true ? '?sessionId=${map[it.course.id]!.sessionId}' : ''}'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                  _RecentSessionsSection(courseId: selectedId),
                  const SizedBox(height: 20),
                  _buildStartForm(items, selectedId),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _buildStartForm(List<CourseListItem> items, String selectedId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'নতুন উপস্থিতি শুরু করুন',
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 12),
            Text('তারিখ', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              title: Text(
                _dateLabel(_date),
                style: GoogleFonts.nunito(),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 1),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            Text('কোর্স', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedId,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                for (final it in items)
                  DropdownMenuItem(
                    value: it.course.id,
                    child: Text(it.course.name, style: GoogleFonts.hindSiliguri()),
                  ),
              ],
              onChanged: (v) => setState(() => _courseId = v),
            ),
            const SizedBox(height: 8),
            Text(
              'enrolled: ${items.firstWhere((e) => e.course.id == selectedId).studentCount} জন শিক্ষার্থী',
              style: GoogleFonts.hindSiliguri(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _starting ? null : () => _startAttendance(selectedId),
                style: FilledButton.styleFrom(
                  backgroundColor: context.themePrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _starting ? 'শুরু হচ্ছে...' : '▶ উপস্থিতি শুরু করুন',
                  style: GoogleFonts.hindSiliguri(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startAttendance(String courseId) async {
    setState(() => _starting = true);
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final existing = await repo.getSessionIdForCourseAndDate(
        courseId: courseId,
        date: _date,
      );
      if (!mounted) return;
      if (existing != null) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('সতর্কতা', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
            content: Text(
              'এই তারিখে এই কোর্সের উপস্থিতি সেশন ইতোমধ্যে আছে। সম্পাদনা চালিয়ে যাবেন?',
              style: GoogleFonts.hindSiliguri(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('না', style: GoogleFonts.hindSiliguri()),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('হ্যাঁ', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
        );
        if (open != true) return;
      }
      _openTaking(courseId, _date);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openTaking(String courseId, DateTime date) {
    context.push('/admin/attendance/$courseId/${_sqlDate(date)}');
  }

  _DailySummary _buildDailySummary(
    List<CourseListItem> items,
    Map<String, AttendanceCourseSessionSummary> map,
  ) {
    final completed = map.values.where((e) => e.isCompleted).length;
    final sessionsToday = map.length;
    var total = 0;
    var present = 0;
    for (final s in map.values) {
      total += s.totalStudents;
      present += s.presentCount;
    }
    final absent = total - present;
    final presentPct = total == 0 ? 0.0 : (present / total) * 100;
    final absentPct = total == 0 ? 0.0 : (absent / total) * 100;
    final below75 = map.values.where((e) {
      if (e.totalStudents <= 0) return false;
      final pct = (e.presentCount / e.totalStudents) * 100;
      return pct < 75;
    }).length;
    return _DailySummary(
      todaySessions: sessionsToday,
      completedSessions: completed,
      presentPct: presentPct,
      absentPct: absentPct,
      below75Count: below75,
      totalCourses: items.length,
    );
  }

  String _dateLabel(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

String _sqlDate(DateTime d) {
  final u = DateTime(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}

class _DailySummary {
  const _DailySummary({
    required this.todaySessions,
    required this.completedSessions,
    required this.presentPct,
    required this.absentPct,
    required this.below75Count,
    required this.totalCourses,
  });

  final int todaySessions;
  final int completedSessions;
  final double presentPct;
  final double absentPct;
  final int below75Count;
  final int totalCourses;
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Text(
      'আজকের তারিখ: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.data});
  final _DailySummary data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatTile(
          title: 'আজকের সেশন',
          value: '${data.completedSessions}/${data.totalCourses}',
          icon: Icons.today_rounded,
          color: const Color(0xFF1E40AF),
        ),
        _StatTile(
          title: 'উপস্থিত',
          value: '${data.presentPct.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: const Color(0xFF15803D),
        ),
        _StatTile(
          title: 'অনুপস্থিত',
          value: '${data.absentPct.toStringAsFixed(1)}%',
          icon: Icons.cancel,
          color: const Color(0xFFB91C1C),
        ),
        _StatTile(
          title: '<75%',
          value: '${data.below75Count} টি সেশন',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFCA8A04),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(title, style: GoogleFonts.hindSiliguri(fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCourseCard extends StatelessWidget {
  const _TodayCourseCard({
    required this.item,
    required this.summary,
    required this.onOpen,
    required this.onReport,
  });

  final CourseListItem item;
  final AttendanceCourseSessionSummary? summary;
  final VoidCallback onOpen;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final done = summary != null && summary!.isCompleted;
    final total = summary?.totalStudents ?? item.studentCount;
    final present = summary?.presentCount ?? 0;
    final pct = total == 0 ? 0.0 : (present / total) * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.pending_rounded,
                  color: done ? const Color(0xFF15803D) : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.course.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              done
                  ? 'সম্পন্ন হয়েছে | $present/$total উপস্থিত (${pct.toStringAsFixed(0)}%)'
                  : summary == null
                      ? 'এখনও শুরু হয়নি | ${item.studentCount} জন enrolled'
                      : 'চলমান | $present/$total চিহ্নিত',
              style: GoogleFonts.hindSiliguri(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (summary != null)
                    TextButton.icon(
                      onPressed: onReport,
                      icon: const Icon(Icons.bar_chart_rounded),
                      label: Text('রিপোর্ট', style: GoogleFonts.hindSiliguri()),
                    ),
                  TextButton.icon(
                    onPressed: summary == null
                        ? onOpen
                        : () {
                            if (done && summary!.sessionId.isNotEmpty) {
                              context.push('/admin/attendance/edit/${summary!.sessionId}');
                            } else {
                              onOpen();
                            }
                          },
                    icon: Icon(done ? Icons.edit : Icons.play_arrow_rounded),
                    label: Text(
                      done ? 'সম্পাদনা' : (summary == null ? 'উপস্থিতি শুরু করুন' : 'চালিয়ে যান'),
                      style: GoogleFonts.hindSiliguri(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionsSection extends ConsumerWidget {
  const _RecentSessionsSection({required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<AttendanceSessionListItem>>(
      future: ref.read(attendanceRepositoryProvider).getRecentSessionsForCourse(courseId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AttendanceSessionListItem>[];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'পূর্বের সেশন (সম্পাদনা)',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items.isEmpty)
                  Text('এই কোর্সে এখনো সেশন নেই', style: GoogleFonts.hindSiliguri())
                else
                  for (final s in items.take(6)) ...[
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: Icon(
                        s.isCompleted ? Icons.check_circle : Icons.pending_rounded,
                        color: s.isCompleted ? const Color(0xFF15803D) : Colors.orange.shade700,
                      ),
                      title: Text(
                        _dateLabel(s.sessionDate),
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'উপস্থিত ${s.presentCount}/${s.totalStudents}',
                        style: GoogleFonts.hindSiliguri(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () => context.push('/admin/attendance/edit/${s.sessionId}'),
                        child: Text('সম্পাদনা', style: GoogleFonts.hindSiliguri()),
                      ),
                    ),
                    if (s != items.take(6).last) const Divider(height: 1),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _dateLabel(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
