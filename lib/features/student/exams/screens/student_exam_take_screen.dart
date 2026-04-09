import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/exam_model.dart';
import '../../../../shared/models/question_model.dart';
import '../repositories/student_exam_repository.dart';

class _TakeBundle {
  const _TakeBundle({
    required this.exam,
    required this.questions,
  });

  final ExamModel exam;
  final List<QuestionModel> questions;
}

class ExamTakingScreen extends StatefulWidget {
  const ExamTakingScreen({super.key, required this.examId});

  final String examId;

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  final _pageController = PageController();
  late Future<_TakeBundle> _future;
  Map<String, String> _answers = {};
  int _index = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TakeBundle> _load() async {
    final repo = StudentExamRepository();
    final exam = await repo.getExam(widget.examId);
    final questions = await repo.listQuestions(widget.examId);
    await repo.ensureSubmissionStarted(widget.examId);
    final raw = await repo.getSubmissionAnswers(widget.examId);
    if (mounted) {
      setState(() {
        _answers = {
          for (final e in raw.entries)
            e.key: e.value?.toString() ?? '',
        };
      });
    }
    return _TakeBundle(exam: exam, questions: questions);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TakeBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('${snap.error}')),
          );
        }
        final b = snap.data!;
        final qs = b.questions;
        if (qs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(b.exam.title, style: GoogleFonts.hindSiliguri())),
            body: Center(
              child: Text('প্রশ্ন নেই', style: GoogleFonts.hindSiliguri()),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(b.exam.title, style: GoogleFonts.hindSiliguri()),
            actions: [
              TextButton(
                onPressed: _submitting ? null : () => _submit(context, b.exam),
                child: Text(
                  'জমা দিন',
                  style: GoogleFonts.hindSiliguri(color: Colors.white),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              LinearProgressIndicator(
                value: (_index + 1) / qs.length,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primary,
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${_index + 1} / ${qs.length}',
                  style: GoogleFonts.nunito(),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: qs.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final q = qs[i];
                    final selected = _answers[q.id];
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          Text(
                            q.questionText,
                            style: GoogleFonts.hindSiliguri(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          _optTile(q, 'A', q.optionA, selected),
                          _optTile(q, 'B', q.optionB, selected),
                          _optTile(q, 'C', q.optionC, selected),
                          _optTile(q, 'D', q.optionD, selected),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _index > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.ease,
                              );
                            }
                          : null,
                      child: Text('আগের', style: GoogleFonts.hindSiliguri()),
                    ),
                    TextButton(
                      onPressed: _index < qs.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.ease,
                              );
                            }
                          : null,
                      child: Text('পরের', style: GoogleFonts.hindSiliguri()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _optTile(
    QuestionModel q,
    String opt,
    String label,
    String? selected,
  ) {
    return RadioListTile<String>(
      title: Text('($opt) $label', style: GoogleFonts.hindSiliguri()),
      value: opt,
      groupValue: selected,
      onChanged: (v) async {
        if (v == null) return;
        setState(() => _answers[q.id] = v);
        await StudentExamRepository().saveAnswers(
          widget.examId,
          Map<String, dynamic>.from(_answers),
        );
      },
    );
  }

  Future<void> _submit(BuildContext context, ExamModel exam) async {
    setState(() => _submitting = true);
    try {
      final repo = StudentExamRepository();
      await repo.saveAnswers(widget.examId, Map<String, dynamic>.from(_answers));
      await repo.submitExam(widget.examId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('জমা হয়েছে', style: GoogleFonts.hindSiliguri())),
        );
        context.go('/student/exams');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
