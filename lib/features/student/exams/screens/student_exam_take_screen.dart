import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:async';

import '../../../../app/i18n/app_localizations.dart';
import '../../../../app/theme.dart';
import '../../../../shared/models/exam_model.dart';
import '../../../../shared/models/question_model.dart';
import '../../widgets/student_drawer.dart';
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
  bool _practiceMode = false;
  bool _showReview = false;
  int? _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TakeBundle> _load() async {
    final repo = StudentExamRepository();
    final exam = await repo.getExam(widget.examId);
    final questions = await repo.listQuestions(widget.examId);
    _practiceMode = exam.status != 'live';
    if (_practiceMode) {
      if (mounted) {
        setState(() {
          _answers = {};
          _remainingSeconds = null;
        });
      }
      return _TakeBundle(exam: exam, questions: questions);
    }

    await repo.ensureSubmissionStarted(widget.examId);
    final state = await repo.getSubmissionState(widget.examId);
    final raw = state == null
        ? <String, dynamic>{}
        : (state['answers'] is Map
              ? Map<String, dynamic>.from(state['answers'] as Map)
              : <String, dynamic>{});
    final startedAt = _tryParseDate(state == null ? null : state['started_at']);
    final duration = exam.durationMinutes * 60;
    final elapsed = startedAt == null
        ? 0
        : DateTime.now().toUtc().difference(startedAt.toUtc()).inSeconds;
    final remain = duration - elapsed;
    if (mounted) {
      setState(() {
        _answers = {
          for (final e in raw.entries)
            e.key: e.value?.toString() ?? '',
        };
        _remainingSeconds = remain > 0 ? remain : 0;
      });
      _startTimer(exam);
    }
    return _TakeBundle(exam: exam, questions: questions);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TakeBundle>(
      future: _future,
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context);
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            drawer: const StudentDrawer(),
            appBar: AppBar(
              leading: const AppBarDrawerLeading(),
              automaticallyImplyLeading: false,
              leadingWidth: leadingWidthForDrawer(context),
              actions: const [AppBarDrawerAction()],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            drawer: const StudentDrawer(),
            appBar: AppBar(
              leading: const AppBarDrawerLeading(),
              automaticallyImplyLeading: false,
              leadingWidth: leadingWidthForDrawer(context),
              actions: const [AppBarDrawerAction()],
            ),
            body: Center(child: Text(l10n.t('load_failed'), style: GoogleFonts.hindSiliguri())),
          );
        }
        final b = snap.data!;
        final qs = b.questions;
        if (qs.isEmpty) {
          return Scaffold(
            drawer: const StudentDrawer(),
            appBar: AppBar(
              leading: const AppBarDrawerLeading(),
              automaticallyImplyLeading: false,
              leadingWidth: leadingWidthForDrawer(context),
              title: Text(b.exam.title, style: GoogleFonts.hindSiliguri()),
              actions: const [AppBarDrawerAction()],
            ),
            body: Center(
              child: Text(l10n.t('exam_no_questions'), style: GoogleFonts.hindSiliguri()),
            ),
          );
        }
        if (b.exam.examMode == 'offline') {
          return Scaffold(
            drawer: const StudentDrawer(),
            appBar: AppBar(
              leading: const AppBarDrawerLeading(),
              automaticallyImplyLeading: false,
              leadingWidth: leadingWidthForDrawer(context),
              title: Text(b.exam.title, style: GoogleFonts.hindSiliguri()),
              actions: const [AppBarDrawerAction()],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.t('exam_offline_notice'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hindSiliguri(fontSize: 16),
                ),
              ),
            ),
          );
        }
        return Scaffold(
          drawer: const StudentDrawer(),
          appBar: AppBar(
            leading: const AppBarDrawerLeading(),
            automaticallyImplyLeading: false,
            leadingWidth: leadingWidthForDrawer(context),
            title: Text(b.exam.title, style: GoogleFonts.hindSiliguri()),
            actions: [
              const AppBarDrawerAction(),
              if (!_practiceMode && _remainingSeconds != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Center(
                    child: Text(
                      _formatRemaining(_remainingSeconds!),
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => _submit(context, b.exam, auto: false),
                child: Text(
                  _practiceMode ? l10n.t('exam_finish_practice') : l10n.t('exam_submit'),
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
                color: context.themePrimary,
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${_index + 1} / ${qs.length}',
                  style: GoogleFonts.nunito(),
                ),
              ),
              Expanded(
                child: _showReview
                    ? _ReviewView(
                        l10n: l10n,
                        exam: b.exam,
                        questions: qs,
                        answers: _answers,
                      )
                    : PageView.builder(
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
                                _MarkdownLatexText(data: q.questionText),
                                if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      q.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Text(
                                        l10n.t('exam_image_load_failed'),
                                        style: GoogleFonts.hindSiliguri(
                                          color: Theme.of(context).colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
              if (_showReview)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton(
                    onPressed: () => context.go('/student/exams'),
                    child: Text(l10n.t('exam_back_to_list'), style: GoogleFonts.hindSiliguri()),
                  ),
                )
              else
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
                      child: Text(l10n.t('exam_prev'), style: GoogleFonts.hindSiliguri()),
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
                      child: Text(l10n.t('exam_next'), style: GoogleFonts.hindSiliguri()),
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
      title: _MarkdownLatexText(data: '($opt) $label'),
      value: opt,
      groupValue: selected,
      onChanged: (v) async {
        if (v == null) return;
        setState(() => _answers[q.id] = v);
        if (!_practiceMode) {
          await StudentExamRepository().saveAnswers(
            widget.examId,
            Map<String, dynamic>.from(_answers),
          );
        }
      },
    );
  }

  Future<void> _submit(BuildContext context, ExamModel exam, {required bool auto}) async {
    if (_showReview) return;
    setState(() => _submitting = true);
    try {
      if (!_practiceMode) {
        final repo = StudentExamRepository();
        await repo.saveAnswers(widget.examId, Map<String, dynamic>.from(_answers));
        await repo.submitExam(widget.examId);
      }
      _timer?.cancel();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _practiceMode
                  ? AppLocalizations.of(context).t('exam_snackbar_practice_done')
                  : (auto
                      ? AppLocalizations.of(context).t('exam_snackbar_auto_submit')
                      : AppLocalizations.of(context).t('exam_snackbar_submitted')),
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        );
        setState(() {
          _showReview = true;
        });
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('failed')}: $e', style: GoogleFonts.hindSiliguri())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startTimer(ExamModel exam) {
    if (_practiceMode || _remainingSeconds == null) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = (_remainingSeconds ?? 0) - 1;
      if (next <= 0) {
        setState(() => _remainingSeconds = 0);
        t.cancel();
        await _submit(context, exam, auto: true);
        return;
      }
      setState(() => _remainingSeconds = next);
    });
  }

  String _formatRemaining(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _MarkdownLatexText extends StatelessWidget {
  const _MarkdownLatexText({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        <md.InlineSyntax>[LatexInlineSyntax()],
      ),
      blockSyntaxes: <md.BlockSyntax>[LatexBlockSyntax()],
      builders: <String, MarkdownElementBuilder>{'latex': LatexElementBuilder()},
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.l10n,
    required this.exam,
    required this.questions,
    required this.answers,
  });

  final AppLocalizations l10n;
  final ExamModel exam;
  final List<QuestionModel> questions;
  final Map<String, String> answers;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final q = questions[i];
        final selected = answers[q.id];
        final isCorrect = selected != null && selected == q.correctOption;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('exam_question_n').replaceAll('{n}', '${i + 1}'),
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _MarkdownLatexText(data: q.questionText),
                const SizedBox(height: 8),
                Text(
                  '${l10n.t('exam_review_your_answer')} ${selected ?? l10n.t('exam_review_skipped')}',
                  style: GoogleFonts.hindSiliguri(
                    color: isCorrect
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                Text(
                  '${l10n.t('exam_review_correct')} ${q.correctOption}',
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
