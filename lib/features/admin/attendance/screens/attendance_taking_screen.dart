import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../core/supabase_client.dart';
import '../../../../core/supabase_storage_image_url.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/providers/courses_provider.dart';
import '../providers/attendance_providers.dart';

/// Step-through attendance for one course and calendar day.
class AttendanceTakingScreen extends ConsumerStatefulWidget {
  const AttendanceTakingScreen({
    super.key,
    required this.courseId,
    required this.date,
  });

  final String courseId;

  /// Calendar date (time ignored).
  final DateTime date;

  @override
  ConsumerState<AttendanceTakingScreen> createState() =>
      _AttendanceTakingScreenState();
}

class _AttendanceTakingScreenState extends ConsumerState<AttendanceTakingScreen> {
  String? _sessionId;
  String _courseName = '';
  List<UserModel> _students = [];
  final Map<String, String> _answers = {};
  final Set<String> _skipped = <String>{};
  int _currentIndex = 0;

  bool _loading = true;
  String? _loadError;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final courseRepo = ref.read(courseRepositoryProvider);
      final attRepo = ref.read(attendanceRepositoryProvider);

      final course = await courseRepo.getCourseById(widget.courseId);
      final sessionId = await attRepo.getOrCreateSession(
        courseId: widget.courseId,
        date: widget.date,
        createdBy: supabaseClient.auth.currentUser?.id,
      );
      final students = await attRepo.getActiveStudentsForCourse(widget.courseId);
      final existing = await attRepo.getRecordStatusesForSession(sessionId);

      if (!mounted) return;
      final initialIndex = students.indexWhere((s) => !existing.containsKey(s.id));
      setState(() {
        _courseName = course.name;
        _sessionId = sessionId;
        _students = students;
        _answers.addAll(existing);
        _currentIndex = initialIndex >= 0 ? initialIndex : 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  int get _answeredCount => _answers.length;
  int get _total => _students.length;

  double get _progressFraction =>
      _total == 0 ? 0 : _answeredCount / _total;

  UserModel? get _currentStudent =>
      _students.isEmpty || _currentIndex < 0 || _currentIndex >= _students.length
          ? null
          : _students[_currentIndex];

  Future<void> _mark(String status) async {
    final student = _currentStudent;
    final sid = _sessionId;
    if (_marking || student == null || sid == null) return;

    setState(() => _marking = true);
    try {
      await ref.read(attendanceRepositoryProvider).upsertAttendanceRecord(
            sessionId: sid,
            studentId: student.id,
            status: status,
          );
      if (!mounted) return;

      setState(() {
        _answers[student.id] = status;
        _skipped.remove(student.id);
      });
      HapticFeedback.mediumImpact();

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() => _marking = false);
      _advanceAfterAction();
    } catch (e) {
      if (!mounted) return;
      setState(() => _marking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সংরক্ষণ ব্যর্থ: $e')),
      );
    }
  }

  void _advanceAfterAction() {
    if (_students.isEmpty) return;
    final nextUnanswered = _students.indexWhere((s) => !_answers.containsKey(s.id));
    if (nextUnanswered >= 0) {
      setState(() => _currentIndex = nextUnanswered);
      return;
    }

    final nextSkipped = _students.indexWhere((s) => _skipped.contains(s.id));
    if (nextSkipped >= 0) {
      setState(() => _currentIndex = nextSkipped);
      return;
    }

    _showCompletionDialog();
  }

  void _skipCurrent() {
    final student = _currentStudent;
    if (student == null) return;
    setState(() => _skipped.add(student.id));
    _advanceAfterAction();
  }

  void _showCompletionDialog() {
    final present = _answers.values.where((e) => e == 'present' || e == 'late').length;
    final absentStudents = _students.where((s) => _answers[s.id] == 'absent').toList();
    final absent = absentStudents.length;
    final total = _students.length;
    final pct = total == 0 ? 0.0 : (present / total) * 100.0;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'সবাই হয়ে গেছে! 🎉',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('উপস্থিত: $present জন (${pct.toStringAsFixed(1)}%)', style: GoogleFonts.hindSiliguri()),
              Text('অনুপস্থিত: $absent জন', style: GoogleFonts.hindSiliguri()),
              Text('মোট: $total জন', style: GoogleFonts.hindSiliguri()),
              if (absentStudents.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'অনুপস্থিত শিক্ষার্থী:',
                  style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final s in absentStudents.take(8))
                  Text(
                    '• ${s.fullNameBn} (${s.studentId ?? "—"})',
                    style: GoogleFonts.hindSiliguri(fontSize: 13),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (!mounted) return;
              final firstAbsent = _students.indexWhere((s) => _answers[s.id] == 'absent');
              if (firstAbsent >= 0) {
                setState(() => _currentIndex = firstAbsent);
              }
            },
            child: Text('🔄 আবার চেক করুন', style: GoogleFonts.hindSiliguri()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (context.mounted) context.pop();
            },
            child: Text('✅ সম্পন্ন করুন', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
  }

  void _goPrev() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  void _openGridNavigator() {
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.52;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = <(int, UserModel)>[];
            for (var i = 0; i < _students.length; i++) {
              final s = _students[i];
              final q = query.trim().toLowerCase();
              if (q.isEmpty ||
                  s.fullNameBn.toLowerCase().contains(q) ||
                  (s.studentId?.toLowerCase().contains(q) ?? false)) {
                filtered.add((i, s));
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'সব শিক্ষার্থী — ${_students.length} জন',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '🔍 নাম/আইডি দিয়ে খুঁজুন...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setModalState(() => query = v),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        _LegendChip(color: const Color(0xFF2E7D32), label: '✅ উপস্থিত'),
                        _LegendChip(color: const Color(0xFFC62828), label: '❌ অনুপস্থিত'),
                        _LegendChip(color: context.themePrimary, label: '🔵 বর্তমান'),
                        _LegendChip(color: Colors.grey.shade600, label: '⬜ চিহ্নিত হয়নি'),
                        _LegendChip(color: const Color(0xFFF59E0B), label: '⚑ পরে দেখব'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: h,
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'কোনো শিক্ষার্থী পাওয়া যায়নি',
                                style: GoogleFonts.hindSiliguri(),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final (originalIndex, u) = filtered[i];
                                final st = _answers[u.id];
                                final isCurrent = originalIndex == _currentIndex;
                                final isSkipped = _skipped.contains(u.id);
                                final color = _statusColor(st);
                                final icon = isCurrent
                                    ? '🔵'
                                    : isSkipped
                                        ? '⚑'
                                        : st == 'present'
                                            ? '✅'
                                            : st == 'absent'
                                                ? '❌'
                                                : '⬜';
                                return Material(
                                  color: isCurrent
                                      ? context.themePrimary.withValues(alpha: 0.22)
                                      : isSkipped
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.24)
                                          : color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      setState(() => _currentIndex = originalIndex);
                                    },
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(icon, style: const TextStyle(fontSize: 16)),
                                        const SizedBox(height: 2),
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: isCurrent
                                              ? context.themePrimary.withValues(alpha: 0.35)
                                              : isSkipped
                                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                                  : color.withValues(alpha: 0.35),
                                          child: Text(
                                            _initials(u),
                                            style: GoogleFonts.nunito(
                                              fontWeight: FontWeight.bold,
                                              color: isCurrent
                                                  ? context.themePrimary.darken(0.3)
                                                  : isSkipped
                                                      ? const Color(0xFF92400E)
                                                      : color.darken(0.3),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          child: Text(
                                            u.fullNameBn,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.hindSiliguri(fontSize: 10),
                                          ),
                                        ),
                                        Text(
                                          '${originalIndex + 1}',
                                          style: GoogleFonts.nunito(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _initials(UserModel u) {
    final name = u.fullNameBn.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final a = parts[0].characters.first;
      final b = parts[1].characters.first;
      return '$a$b';
    }
    return name.characters.take(2).join();
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'present':
        return const Color(0xFF2E7D32);
      case 'absent':
        return const Color(0xFFC62828);
      case 'late':
        return const Color(0xFF2563EB);
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDateBn(widget.date);

    if (_loading) {
      return AdminResponsiveScaffold(
        constrainBodyWidth: false,
        title: Text('হাজিরা', style: GoogleFonts.hindSiliguri()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return AdminResponsiveScaffold(
        constrainBodyWidth: false,
        title: Text('হাজিরা', style: GoogleFonts.hindSiliguri()),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_students.isEmpty) {
      return AdminResponsiveScaffold(
        constrainBodyWidth: false,
        title: Text('হাজিরা', style: GoogleFonts.hindSiliguri()),
        body: Center(
          child: Text(
            'এই কোর্সে কোনো সক্রিয় শিক্ষার্থী নেই।',
            style: GoogleFonts.hindSiliguri(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final student = _currentStudent!;

    return AdminResponsiveScaffold(
      constrainBodyWidth: false,
      toolbarHeight: 96,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.hindSiliguri(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: GoogleFonts.nunito(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '$_answeredCount/$_total সম্পন্ন',
            style: GoogleFonts.hindSiliguri(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.themePrimary,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openGridNavigator,
        backgroundColor: context.themePrimary,
        child: const Icon(Icons.grid_view_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: _progressFraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: AppTheme.accent,
          ),
          Expanded(
            child: Center(
              child: FractionallySizedBox(
                heightFactor: 0.6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    transitionBuilder: (child, animation) {
                      final tween = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      );
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: tween.animate(animation), child: child),
                      );
                    },
                    child: Card(
                      key: ValueKey(student.id),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Avatar(student: student, size: 80),
                            const SizedBox(height: 16),
                            Text(
                              student.fullNameBn,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              student.studentId?.isNotEmpty == true
                                  ? student.studentId!
                                  : '—',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_skipped.contains(student.id)) ...[
                              const SizedBox(height: 6),
                              Text(
                                '⚑ পরে দেখব তালিকায় আছে',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 12,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final gap = constraints.maxWidth * 0.05;
                                final btnW = constraints.maxWidth * 0.45;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: btnW,
                                      height: 72,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E7D32),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _marking
                                            ? null
                                            : () => _mark('present'),
                                        child: Text(
                                          '✅ উপস্থিত',
                                          style: GoogleFonts.hindSiliguri(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: gap),
                                    SizedBox(
                                      width: btnW,
                                      height: 72,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFC62828),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _marking
                                            ? null
                                            : () => _mark('absent'),
                                        child: Text(
                                          '❌ অনুপস্থিত',
                                          style: GoogleFonts.hindSiliguri(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentIndex <= 0 ? null : _goPrev,
                  child: Text('◀ আগের', style: GoogleFonts.hindSiliguri()),
                ),
                TextButton(
                  onPressed: _marking ? null : _skipCurrent,
                  child: Text('⚑ পরে দেখব', style: GoogleFonts.hindSiliguri()),
                ),
                TextButton(
                  onPressed: _openGridNavigator,
                  child: Text('🗂️ তালিকা', style: GoogleFonts.hindSiliguri()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateBn(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.student, required this.size});

  final UserModel student;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = student.avatarUrl;
    final r = size / 2;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: r,
        backgroundColor: Colors.grey.shade300,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: supabaseStorageRenderImageUrl(url, width: (size * 2).round(), height: (size * 2).round()),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => SizedBox(
              width: size,
              height: size,
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) =>
                _InitialsFallback(student: student, size: size),
          ),
        ),
      );
    }
    return _InitialsFallback(student: student, size: size);
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.student, required this.size});

  final UserModel student;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = student.fullNameBn.trim();
    String initials;
    if (name.isEmpty) {
      initials = '?';
    } else {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials =
            '${parts[0].characters.first}${parts[1].characters.first}';
      } else {
        initials = name.characters.take(2).join();
      }
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.themePrimary.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: GoogleFonts.nunito(
          fontSize: size * 0.28,
          fontWeight: FontWeight.bold,
          color: context.themePrimary,
        ),
      ),
    );
  }
}

extension on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.hindSiliguri(fontSize: 11),
      ),
    );
  }
}
