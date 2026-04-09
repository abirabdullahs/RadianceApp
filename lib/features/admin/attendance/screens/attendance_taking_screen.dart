import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/supabase_client.dart';
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
      setState(() {
        _courseName = course.name;
        _sessionId = sessionId;
        _students = students;
        _answers.addAll(existing);
        _currentIndex = 0;
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
      });
      HapticFeedback.mediumImpact();

      final wasLastIndex = _currentIndex >= _students.length - 1;

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() => _marking = false);

      if (wasLastIndex) {
        _showCompletionDialog();
      } else {
        setState(() => _currentIndex++);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _marking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সংরক্ষণ ব্যর্থ: $e')),
      );
    }
  }

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'হাজিরা সম্পন্ন',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'এই ক্লাসের উপস্থিতি রেকর্ড সম্পন্ন হয়েছে।',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (context.mounted) context.pop();
            },
            child: Text('ঠিক আছে', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
  }

  void _goPrev() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  void _goNext() {
    if (_currentIndex >= _students.length - 1) return;
    setState(() => _currentIndex++);
  }

  void _openGridNavigator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final h = MediaQuery.sizeOf(ctx).height * 0.55;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'শিক্ষার্থী নির্বাচন',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: h,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _students.length,
                    itemBuilder: (context, i) {
                      final u = _students[i];
                      final st = _answers[u.id];
                      final color = _statusColor(st);
                      return Material(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            setState(() => _currentIndex = i);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: color.withValues(alpha: 0.35),
                                child: Text(
                                  _initials(u),
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.bold,
                                    color: color.darken(0.3),
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
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = _formatDateBn(widget.date);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('হাজিরা', style: GoogleFonts.hindSiliguri())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text('হাজিরা', style: GoogleFonts.hindSiliguri())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_students.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('হাজিরা', style: GoogleFonts.hindSiliguri())),
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

    return Scaffold(
      appBar: AppBar(
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
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openGridNavigator,
        backgroundColor: AppTheme.primary,
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
                  child: Card(
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
                                    height: 64,
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
                                    height: 64,
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
                  onPressed: _currentIndex >= _students.length - 1
                      ? null
                      : _goNext,
                  child: Text('পরের ▶', style: GoogleFonts.hindSiliguri()),
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
            imageUrl: url,
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
      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: GoogleFonts.nunito(
          fontSize: size * 0.28,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
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
