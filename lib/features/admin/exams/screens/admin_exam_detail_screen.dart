import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/exam_model.dart';
import '../../../../shared/models/question_model.dart';
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(e.title, style: GoogleFonts.hindSiliguri()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addQuestion(context),
        backgroundColor: AppTheme.primary,
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
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: Text('শেষ করুন', style: GoogleFonts.hindSiliguri()),
                onPressed: () => _setStatus('ended'),
              ),
              ActionChip(
                label: Text('ফল প্রকাশ', style: GoogleFonts.hindSiliguri()),
                onPressed: _publishing ? null : () => _publish(context),
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

  Future<void> _addQuestion(BuildContext context) async {
    final text = TextEditingController();
    final a = TextEditingController();
    final b = TextEditingController();
    final c = TextEditingController();
    final d = TextEditingController();
    String correct = 'A';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('প্রশ্ন যোগ', style: GoogleFonts.hindSiliguri()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  decoration: const InputDecoration(labelText: 'প্রশ্ন'),
                  style: GoogleFonts.hindSiliguri(),
                  maxLines: 3,
                ),
                TextField(controller: a, decoration: const InputDecoration(labelText: 'A')),
                TextField(controller: b, decoration: const InputDecoration(labelText: 'B')),
                TextField(controller: c, decoration: const InputDecoration(labelText: 'C')),
                TextField(controller: d, decoration: const InputDecoration(labelText: 'D')),
                DropdownButton<String>(
                  value: correct,
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('সঠিক: A')),
                    DropdownMenuItem(value: 'B', child: Text('সঠিক: B')),
                    DropdownMenuItem(value: 'C', child: Text('সঠিক: C')),
                    DropdownMenuItem(value: 'D', child: Text('সঠিক: D')),
                  ],
                  onChanged: (v) => correct = v ?? 'A',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            FilledButton(
              onPressed: () async {
                await ExamRepository().addQuestion(
                  examId: widget.examId,
                  questionText: text.text.trim(),
                  optionA: a.text.trim(),
                  optionB: b.text.trim(),
                  optionC: c.text.trim(),
                  optionD: d.text.trim(),
                  correctOption: correct,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                widget.onRefresh();
                setState(() {});
              },
              child: Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri()),
            ),
          ],
        );
      },
    );

    text.dispose();
    a.dispose();
    b.dispose();
    c.dispose();
    d.dispose();
  }
}
