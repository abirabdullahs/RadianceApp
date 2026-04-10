import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:convert';
import 'dart:io';

import '../../../../app/theme.dart';
import '../../../../shared/models/chapter_model.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/exam_model.dart';
import '../../../../shared/models/question_model.dart';
import '../../../admin/courses/repositories/course_repository.dart';
import '../../../admin/students/repositories/student_repository.dart';
import '../../../../shared/models/user_model.dart';
import '../repositories/exam_repository.dart';
import '../services/result_calculator.dart';

final _examDetailProvider =
    FutureProvider.autoDispose.family<_ExamDetail, String>((ref, examId) async {
  final repo = ExamRepository();
  final exam = await repo.getExam(examId);
  final questions = await repo.listQuestions(examId);
  return _ExamDetail(exam: exam, questions: questions);
});

class _ExamDetail {
  const _ExamDetail({required this.exam, required this.questions});

  final ExamModel exam;
  final List<QuestionModel> questions;
}

class AdminExamDetailScreen extends ConsumerWidget {
  const AdminExamDetailScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_examDetailProvider(examId));

    return async.when(
      data: (d) => _ExamDetailBody(
        examId: examId,
        detail: d,
        onRefresh: () => ref.invalidate(_examDetailProvider(examId)),
      ),
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

class _ExamDetailBody extends StatefulWidget {
  const _ExamDetailBody({
    required this.examId,
    required this.detail,
    required this.onRefresh,
  });

  final String examId;
  final _ExamDetail detail;
  final VoidCallback onRefresh;

  @override
  State<_ExamDetailBody> createState() => _ExamDetailBodyState();
}

class _ExamDetailBodyState extends State<_ExamDetailBody> {
  bool _publishing = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.detail.exam;
    final qs = widget.detail.questions;

    return AdminResponsiveScaffold(
      title: Text(e.title, style: GoogleFonts.hindSiliguri()),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addQuestion(context),
        backgroundColor: context.themePrimary,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'স্ট্যাটাস: ${e.status}',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'পরীক্ষা সেটিংস',
                    style: GoogleFonts.hindSiliguri(
                      fontWeight: FontWeight.w700,
                      color: context.themePrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('মোড: ${e.examMode}', style: GoogleFonts.hindSiliguri()),
                  Text(
                    'শিডিউল: ${_fmtSchedule(e.startTime, e.endTime)}',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                  Text(
                    'সিলেক্টেড চ্যাপ্টার: ${e.chapterIds.length}',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _editScopeAndSchedule(context, e),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: Text('চ্যাপ্টার/শিডিউল এডিট', style: GoogleFonts.hindSiliguri()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: Text('শেষ করুন', style: GoogleFonts.hindSiliguri()),
                onPressed: () => _setStatus('ended'),
              ),
              ActionChip(
                label: Text('ফল প্রকাশ', style: GoogleFonts.hindSiliguri()),
                onPressed: _publishing
                    ? null
                    : () {
                        if (e.examMode == 'offline') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'অফলাইন পরীক্ষার জন্য "অফলাইন রেজাল্ট আপলোড" ব্যবহার করুন।',
                                style: GoogleFonts.hindSiliguri(),
                              ),
                            ),
                          );
                          return;
                        }
                        _publish(context);
                      },
              ),
              ActionChip(
                label: Text('JSON থেকে প্রশ্ন', style: GoogleFonts.hindSiliguri()),
                onPressed: () => _importQuestionsFromJson(context),
              ),
              if (e.examMode == 'offline')
                ActionChip(
                  label: Text('অফলাইন রেজাল্ট আপলোড', style: GoogleFonts.hindSiliguri()),
                  onPressed: () => _openOfflineResultUploader(context, e),
                ),
              if (e.examMode == 'offline')
                ActionChip(
                  label: Text('JSON রেজাল্ট আপলোড', style: GoogleFonts.hindSiliguri()),
                  onPressed: () => _importOfflineResultsFromJson(context, e),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'প্রশ্ন (${qs.length})',
            style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (qs.isEmpty)
            Text('কোনো প্রশ্ন নেই — + চাপুন', style: GoogleFonts.hindSiliguri())
          else
            ...qs.map(
              (q) => Card(
                child: ListTile(
                  title: Text(
                    q.questionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(),
                  ),
                  subtitle: Text(
                    'সঠিক: ${q.correctOption} · ${q.marks} নম্বর',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ExamRepository().deleteQuestion(q.id);
                      widget.onRefresh();
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setStatus(String status) async {
    await ExamRepository().setExamStatus(widget.examId, status);
    widget.onRefresh();
    if (mounted) setState(() {});
  }

  Future<void> _publish(BuildContext context) async {
    setState(() => _publishing = true);
    try {
      await ExamRepository().setExamStatus(widget.examId, 'ended');
      await ResultCalculator().calculateResults(widget.examId);
      widget.onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ফলাফল প্রকাশিত',
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _editScopeAndSchedule(BuildContext context, ExamModel exam) async {
    final repo = CourseRepository();
    final subjects = await repo.getSubjects(exam.courseId);
    String? selectedSubjectId = exam.subjectId ?? (subjects.isNotEmpty ? subjects.first.id : null);
    var chapters = <ChapterModel>[];
    if (selectedSubjectId != null) {
      chapters = await repo.getChapters(selectedSubjectId);
    }
    final selectedChapters = <String>{...exam.chapterIds};
    var startTime = exam.startTime;
    var endTime = exam.endTime;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('সিলেবাস ও শিডিউল এডিট', style: GoogleFonts.hindSiliguri()),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSubjectId,
                    decoration: const InputDecoration(labelText: 'সাবজেক্ট'),
                    items: [
                      for (final s in subjects)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) async {
                      selectedSubjectId = v;
                      selectedChapters.clear();
                      if (v != null) {
                        chapters = await repo.getChapters(v);
                      } else {
                        chapters = <ChapterModel>[];
                      }
                      setLocal(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('চ্যাপ্টার (একাধিক)', style: GoogleFonts.hindSiliguri()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in chapters)
                        FilterChip(
                          selected: selectedChapters.contains(c.id),
                          label: Text(c.name, style: GoogleFonts.hindSiliguri(fontSize: 13)),
                          onSelected: (v) {
                            setLocal(() {
                              if (v) {
                                selectedChapters.add(c.id);
                              } else {
                                selectedChapters.remove(c.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      startTime == null ? 'শুরু সময়' : 'শুরু: ${_fmtDateTime(startTime!)}',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final next = await _pickDateTime(ctx, startTime);
                      if (next != null) setLocal(() => startTime = next);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      endTime == null ? 'শেষ সময়' : 'শেষ: ${_fmtDateTime(endTime!)}',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    trailing: const Icon(Icons.event_available),
                    onTap: () async {
                      final next = await _pickDateTime(ctx, endTime);
                      if (next != null) setLocal(() => endTime = next);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            FilledButton(
              onPressed: () async {
                if (selectedSubjectId == null || selectedChapters.isEmpty) return;
                final updated = ExamModel(
                  id: exam.id,
                  courseId: exam.courseId,
                  subjectId: selectedSubjectId,
                  chapterIds: selectedChapters.toList(),
                  examMode: exam.examMode,
                  title: exam.title,
                  instructions: exam.instructions,
                  durationMinutes: exam.durationMinutes,
                  startTime: startTime,
                  endTime: endTime,
                  totalMarks: exam.totalMarks,
                  passMarks: exam.passMarks,
                  shuffleQuestions: exam.shuffleQuestions,
                  showResultImmediately: exam.showResultImmediately,
                  negativeMarking: exam.negativeMarking,
                  status: exam.status,
                  createdBy: exam.createdBy,
                  createdAt: exam.createdAt,
                  updatedAt: exam.updatedAt,
                );
                await ExamRepository().updateExam(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onRefresh();
                setState(() {});
              },
              child: Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addQuestion(BuildContext context) async {
    final text = TextEditingController();
    final imageUrl = TextEditingController();
    final a = TextEditingController();
    final aImg = TextEditingController();
    final b = TextEditingController();
    final bImg = TextEditingController();
    final c = TextEditingController();
    final cImg = TextEditingController();
    final d = TextEditingController();
    final dImg = TextEditingController();
    String correct = 'A';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text('প্রশ্ন যোগ', style: GoogleFonts.hindSiliguri()),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: text,
                      decoration: const InputDecoration(labelText: 'প্রশ্ন (MD + LaTeX)'),
                      style: GoogleFonts.hindSiliguri(),
                      maxLines: 4,
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(labelText: 'প্রশ্ন ইমেজ URL (ঐচ্ছিক)'),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 12),
                    _optionEditor('A', a, aImg, setLocal),
                    _optionEditor('B', b, bImg, setLocal),
                    _optionEditor('C', c, cImg, setLocal),
                    _optionEditor('D', d, dImg, setLocal),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: correct,
                      decoration: const InputDecoration(labelText: 'সঠিক উত্তর'),
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'B', child: Text('B')),
                        DropdownMenuItem(value: 'C', child: Text('C')),
                        DropdownMenuItem(value: 'D', child: Text('D')),
                      ],
                      onChanged: (v) => setLocal(() => correct = v ?? 'A'),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'লাইভ প্রিভিউ',
                      style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MdLatex(data: text.text.trim().isEmpty ? 'প্রশ্ন প্রিভিউ' : text.text),
                          if (imageUrl.text.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Image.network(
                                imageUrl.text.trim(),
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  'প্রশ্ন ইমেজ প্রিভিউ ব্যর্থ',
                                  style: GoogleFonts.hindSiliguri(color: Theme.of(ctx).colorScheme.error),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
              FilledButton(
                onPressed: () async {
                  final qText = text.text.trim();
                  if (qText.isEmpty) return;
                  await ExamRepository().addQuestion(
                    examId: widget.examId,
                    questionText: qText,
                    imageUrl: imageUrl.text.trim().isEmpty ? null : imageUrl.text.trim(),
                    optionA: _mergeTextAndImage(a.text, aImg.text),
                    optionB: _mergeTextAndImage(b.text, bImg.text),
                    optionC: _mergeTextAndImage(c.text, cImg.text),
                    optionD: _mergeTextAndImage(d.text, dImg.text),
                    correctOption: correct,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  widget.onRefresh();
                  setState(() {});
                },
                child: Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
        );
      },
    );

    text.dispose();
    imageUrl.dispose();
    a.dispose();
    aImg.dispose();
    b.dispose();
    bImg.dispose();
    c.dispose();
    cImg.dispose();
    d.dispose();
    dImg.dispose();
  }

  Widget _optionEditor(
    String label,
    TextEditingController text,
    TextEditingController image,
    void Function(VoidCallback fn) setLocal,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          TextField(
            controller: text,
            decoration: InputDecoration(labelText: 'Option $label (MD + LaTeX)'),
            onChanged: (_) => setLocal(() {}),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: image,
            decoration: InputDecoration(labelText: 'Option $label image URL (ঐচ্ছিক)'),
            onChanged: (_) => setLocal(() {}),
          ),
        ],
      ),
    );
  }

  String _mergeTextAndImage(String text, String imageUrl) {
    final t = text.trim();
    final i = imageUrl.trim();
    if (i.isEmpty) return t;
    if (t.isEmpty) return '![option]($i)';
    return '$t\n\n![option]($i)';
  }

  Future<void> _importQuestionsFromJson(BuildContext context) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw Exception('JSON must be an array of questions');
      }

      var inserted = 0;
      for (var i = 0; i < decoded.length; i++) {
        final q = Map<String, dynamic>.from(decoded[i] as Map);
        final options = q['options'];
        final optionA = q['optionA'] ?? (options is Map ? options['A'] : null);
        final optionB = q['optionB'] ?? (options is Map ? options['B'] : null);
        final optionC = q['optionC'] ?? (options is Map ? options['C'] : null);
        final optionD = q['optionD'] ?? (options is Map ? options['D'] : null);
        final text = (q['questionText'] ?? q['question'] ?? '').toString().trim();
        if (text.isEmpty ||
            optionA == null ||
            optionB == null ||
            optionC == null ||
            optionD == null) {
          continue;
        }
        await ExamRepository().addQuestion(
          examId: widget.examId,
          questionText: text,
          imageUrl: q['imageUrl']?.toString(),
          optionA: optionA.toString(),
          optionB: optionB.toString(),
          optionC: optionC.toString(),
          optionD: optionD.toString(),
          correctOption: (q['correctOption'] ?? 'A').toString().toUpperCase(),
          marks: (q['marks'] is num) ? (q['marks'] as num).toDouble() : 1,
          displayOrder: i,
          explanation: q['explanation']?.toString(),
        );
        inserted++;
      }
      widget.onRefresh();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$inserted টি প্রশ্ন ইমপোর্ট হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openOfflineResultUploader(BuildContext context, ExamModel exam) async {
    final totalCtl = TextEditingController(
      text: (exam.totalMarks != null && exam.totalMarks! > 0)
          ? exam.totalMarks!.toStringAsFixed(0)
          : '',
    );
    final students = await StudentRepository().getStudents(courseId: exam.courseId);
    final marks = <String, TextEditingController>{
      for (final s in students) s.id: TextEditingController(),
    };
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('অফলাইন রেজাল্ট এন্ট্রি', style: GoogleFonts.hindSiliguri()),
        content: SizedBox(
          width: 700,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: totalCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Marks'),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${s.fullNameBn} (${s.studentId ?? 'N/A'})',
                        style: GoogleFonts.hindSiliguri(fontSize: 14),
                      ),
                      trailing: SizedBox(
                        width: 90,
                        child: TextField(
                          controller: marks[s.id],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'Mark'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _downloadOfflineJsonTemplate(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('JSON টেমপ্লেট', style: GoogleFonts.hindSiliguri()),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          FilledButton(
            onPressed: () async {
              final total = double.tryParse(totalCtl.text.trim());
              if (total == null || total <= 0) return;
              final inputs = <OfflineResultInput>[];
              for (final s in students) {
                final raw = marks[s.id]!.text.trim();
                if (raw.isEmpty) continue;
                final score = double.tryParse(raw);
                if (score == null) continue;
                inputs.add(OfflineResultInput(studentId: s.id, obtainedMarks: score));
              }
              await ResultCalculator().publishOfflineResults(
                examId: exam.id,
                totalMarks: total,
                inputs: inputs,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              widget.onRefresh();
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('অফলাইন রেজাল্ট প্রকাশিত', style: GoogleFonts.hindSiliguri())),
                );
              }
            },
            child: Text('প্রকাশ করুন', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
    totalCtl.dispose();
    for (final c in marks.values) {
      c.dispose();
    }
  }

  Future<void> _downloadOfflineJsonTemplate(BuildContext context) async {
    try {
      const sample = {
        'totalMarks': 100,
        'results': [
          {'student_id': 'RCC123456789', 'obtained': 78},
          {'student_id': 'RCC987654321', 'obtained': 65.5},
        ],
      };
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save offline result template',
        fileName: 'offline_result_template.json',
      );
      if (path == null || path.isEmpty) return;
      await File(path).writeAsString(
        const JsonEncoder.withIndent('  ').convert(sample),
        flush: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('টেমপ্লেট সেভ হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _importOfflineResultsFromJson(BuildContext context, ExamModel exam) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) return;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('JSON format invalid');
      }
      final total = (decoded['totalMarks'] as num?)?.toDouble() ??
          double.tryParse(decoded['totalMarks']?.toString() ?? '');
      if (total == null || total <= 0) throw Exception('totalMarks required');
      final rows = decoded['results'];
      if (rows is! List) throw Exception('results list required');

      final students = await StudentRepository().getStudents(courseId: exam.courseId);
      final byStudentId = <String, UserModel>{
        for (final s in students)
          if (s.studentId != null) s.studentId!.replaceAll(RegExp(r'\s+'), '').toUpperCase(): s,
      };
      final inputs = <OfflineResultInput>[];
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final sidRaw = (m['student_id'] ?? m['studentId'] ?? '').toString();
        final sid = sidRaw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
        final score = (m['obtained'] as num?)?.toDouble() ??
            double.tryParse((m['obtained'] ?? '').toString());
        if (sid.isEmpty || score == null) continue;
        final student = byStudentId[sid];
        if (student == null) continue;
        inputs.add(OfflineResultInput(studentId: student.id, obtainedMarks: score));
      }
      await ResultCalculator().publishOfflineResults(
        examId: exam.id,
        totalMarks: total,
        inputs: inputs,
      );
      widget.onRefresh();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inputs.length} জনের রেজাল্ট আপলোড হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _fmtSchedule(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'এখনও সেট করা হয়নি';
    if (start != null && end != null) {
      return '${_fmtDateTime(start)} - ${_fmtDateTime(end)}';
    }
    return start != null ? _fmtDateTime(start) : _fmtDateTime(end!);
  }

  String _fmtDateTime(DateTime dt) {
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mn = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} $hh:$mn';
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? seed) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: seed ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed ?? now),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }
}

class _MdLatex extends StatelessWidget {
  const _MdLatex({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        <md.InlineSyntax>[LatexInlineSyntax()],
      ),
      blockSyntaxes: <md.BlockSyntax>[LatexBlockSyntax()],
      builders: <String, MarkdownElementBuilder>{'latex': LatexElementBuilder()},
    );
  }
}
