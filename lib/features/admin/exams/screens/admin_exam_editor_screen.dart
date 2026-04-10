import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/chapter_model.dart';
import '../../../../shared/models/subject_model.dart';
import '../../../notifications/repositories/notifications_repository.dart';
import '../../courses/repositories/course_repository.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../courses/providers/courses_provider.dart';
import '../repositories/exam_repository.dart';

/// Creates a new exam (draft) then navigates to detail.
class AdminExamEditorScreen extends ConsumerStatefulWidget {
  const AdminExamEditorScreen({super.key});

  @override
  ConsumerState<AdminExamEditorScreen> createState() =>
      _AdminExamEditorScreenState();
}

class _AdminExamEditorScreenState extends ConsumerState<AdminExamEditorScreen> {
  final _title = TextEditingController();
  final _duration = TextEditingController(text: '30');
  final _totalMarks = TextEditingController(text: '30');
  final _passMarks = TextEditingController(text: '15');
  final _neg = TextEditingController(text: '0');
  String _examMode = 'online';
  String? _courseId;
  String? _subjectId;
  DateTime? _startTime;
  DateTime? _endTime;
  List<SubjectModel> _subjects = const [];
  List<ChapterModel> _chapters = const [];
  final Set<String> _selectedChapterIds = <String>{};
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _totalMarks.dispose();
    _passMarks.dispose();
    _neg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return AdminResponsiveScaffold(
      title: Text('নতুন পরীক্ষা', style: GoogleFonts.hindSiliguri()),
      body: coursesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('প্রথমে একটি কোর্স যোগ করুন', style: GoogleFonts.hindSiliguri()),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _courseId ?? items.first.course.id,
                decoration: InputDecoration(
                  labelText: 'কোর্স',
                  labelStyle: GoogleFonts.hindSiliguri(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  for (final it in items)
                    DropdownMenuItem(
                      value: it.course.id,
                      child: Text(it.course.name, style: GoogleFonts.hindSiliguri()),
                    ),
                ],
                onChanged: (v) async {
                  final id = v ?? items.first.course.id;
                  setState(() {
                    _courseId = id;
                    _subjectId = null;
                    _subjects = const [];
                    _chapters = const [];
                    _selectedChapterIds.clear();
                  });
                  await _loadSubjects(id);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _examMode,
                decoration: InputDecoration(
                  labelText: 'মোড',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'offline', child: Text('Offline')),
                ],
                onChanged: (v) => setState(() => _examMode = v ?? 'online'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _subjectId,
                decoration: InputDecoration(
                  labelText: 'সাবজেক্ট',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  for (final s in _subjects)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name, style: GoogleFonts.hindSiliguri()),
                    ),
                ],
                onChanged: (v) async {
                  setState(() {
                    _subjectId = v;
                    _chapters = const [];
                    _selectedChapterIds.clear();
                  });
                  if (v != null) await _loadChapters(v);
                },
              ),
              const SizedBox(height: 12),
              if (_chapters.isNotEmpty) ...[
                Text('চ্যাপ্টার (একাধিক সিলেক্ট)', style: GoogleFonts.hindSiliguri()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _chapters)
                      FilterChip(
                        selected: _selectedChapterIds.contains(c.id),
                        label: Text(c.name, style: GoogleFonts.hindSiliguri(fontSize: 13)),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _selectedChapterIds.add(c.id);
                            } else {
                              _selectedChapterIds.remove(c.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'শিরোনাম',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                title: Text(
                  _startTime == null
                      ? 'শুরু সময় নির্বাচন'
                      : 'শুরু: ${_fmt(_startTime!)}',
                  style: GoogleFonts.hindSiliguri(),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final dt = await _pickDateTime(context, _startTime);
                  if (dt != null) setState(() => _startTime = dt);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                title: Text(
                  _endTime == null ? 'শেষ সময় নির্বাচন' : 'শেষ: ${_fmt(_endTime!)}',
                  style: GoogleFonts.hindSiliguri(),
                ),
                trailing: const Icon(Icons.event_available),
                onTap: () async {
                  final dt = await _pickDateTime(context, _endTime);
                  if (dt != null) setState(() => _endTime = dt);
                },
              ),
              if (_examMode == 'online') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'সময় (মিনিট)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _totalMarks,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'মোট নম্বর',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passMarks,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'পাস নম্বর',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _neg,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'নেগেটিভ মার্কিং (প্রতি ভুল)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await _save(context, items);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: context.themePrimary,
                  padding: const EdgeInsets.all(16),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri(color: Colors.white)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    List<CourseListItem> courseItems,
  ) async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শিরোনাম লিখুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    if (_subjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সাবজেক্ট নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    if (_selectedChapterIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('কমপক্ষে ১টি চ্যাপ্টার নির্বাচন করুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শিডিউল দিন (শুরু/শেষ)', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final cid = _courseId ?? courseItems.first.course.id;
      final exam = await ExamRepository().createExam(
        courseId: cid,
        subjectId: _subjectId,
        chapterIds: _selectedChapterIds.toList(),
        examMode: _examMode,
        title: title,
        durationMinutes: _examMode == 'online' ? (int.tryParse(_duration.text) ?? 30) : 30,
        totalMarks: _examMode == 'online' ? double.tryParse(_totalMarks.text) : null,
        passMarks: _examMode == 'online' ? double.tryParse(_passMarks.text) : null,
        negativeMarking: _examMode == 'online' ? (double.tryParse(_neg.text) ?? 0) : 0,
        status: 'scheduled',
        startTime: _startTime,
        endTime: _endTime,
      );
      await NotificationsRepository().sendExamScheduleNotice(
        courseId: cid,
        examId: exam.id,
        examTitle: exam.title,
        examMode: exam.examMode,
        startTime: _startTime!,
      );
      if (context.mounted) {
        context.go('/admin/exams/${exam.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSubjects(String courseId) async {
    final subjects = await CourseRepository().getSubjects(courseId);
    if (!mounted) return;
    setState(() => _subjects = subjects);
  }

  Future<void> _loadChapters(String subjectId) async {
    final chapters = await CourseRepository().getChapters(subjectId);
    if (!mounted) return;
    setState(() => _chapters = chapters);
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? seed) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 5);
    final date = await showDatePicker(
      context: context,
      initialDate: seed ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (date == null) return null;
    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
