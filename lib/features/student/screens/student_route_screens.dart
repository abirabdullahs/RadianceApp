import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/providers/auth_provider.dart';
import '../../question_bank/providers/qbank_providers.dart';
import '../../question_bank/repositories/qbank_repository.dart';
import '../../question_bank/widgets/mixed_content_renderer.dart';
import '../../../shared/models/qbank_models.dart';
import '../widgets/student_drawer.dart';

class QBankScreen extends ConsumerStatefulWidget {
  const QBankScreen({super.key});

  @override
  ConsumerState<QBankScreen> createState() => _QBankScreenState();
}

class _QBankScreenState extends ConsumerState<QBankScreen>
    with SingleTickerProviderStateMixin {
  String? _sessionId;
  String? _subjectId;
  String? _chapterId;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final sessionsAsync = ref.watch(qbankSessionsProvider);

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('প্রশ্ন ব্যাংক', style: GoogleFonts.hindSiliguri()),
        actions: [
          IconButton(
            tooltip: 'রিফ্রেশ',
            onPressed: () {
              ref.invalidate(qbankSessionsProvider);
              if (_sessionId != null) ref.invalidate(qbankSubjectsProvider(_sessionId!));
              if (_subjectId != null) ref.invalidate(qbankChaptersProvider(_subjectId!));
              if (_chapterId != null) {
                ref.invalidate(qbankMcqQuestionsProvider(QbankQuestionQuery(chapterId: _chapterId!)));
                ref.invalidate(qbankCqQuestionsProvider(QbankQuestionQuery(chapterId: _chapterId!)));
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Bookmarks',
            onPressed: () async {
              final user = await ref.read(currentUserProvider.future);
              final uid = user?.id;
              if (uid == null || !context.mounted) return;
              await _showBookmarksDialog(context, uid);
            },
            icon: const Icon(Icons.bookmark_outline),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () async {
              final selected = await _openSearchSheet(
                context,
                initialSessionId: _sessionId,
                initialSubjectId: _subjectId,
              );
              if (selected == null) return;
              if (!mounted) return;
              setState(() {
                _sessionId = selected.sessionId;
                _subjectId = selected.subjectId;
                _chapterId = selected.chapterId;
                _tab.index = selected.questionType == 'cq' ? 1 : 0;
              });
            },
            icon: const Icon(Icons.search),
          ),
          const AppBarDrawerAction(),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(child: Text('এখনো কোনো সেশন নেই', style: GoogleFonts.hindSiliguri()));
          }
          _sessionId ??= sessions.first.id;
          final subjectsAsync = ref.watch(qbankSubjectsProvider(_sessionId!));
          return subjectsAsync.when(
            data: (subjects) {
              if (subjects.isEmpty) {
                return Center(child: Text('এই সেশনে কোনো বিষয় নেই', style: GoogleFonts.hindSiliguri()));
              }
              _subjectId ??= subjects.first.id;
              final chaptersAsync = ref.watch(qbankChaptersProvider(_subjectId!));
              return chaptersAsync.when(
                data: (chapters) {
                  if (chapters.isEmpty) {
                    return Center(
                      child: Text('এই বিষয়ে কোনো অধ্যায় নেই', style: GoogleFonts.hindSiliguri()),
                    );
                  }
                  _chapterId ??= chapters.first.id;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _sessionId,
                              decoration: InputDecoration(
                                labelText: 'সেশন',
                                labelStyle: GoogleFonts.hindSiliguri(),
                                border: const OutlineInputBorder(),
                              ),
                              items: sessions
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s.id,
                                      child: Text('${s.nameBn} (${s.name})', style: GoogleFonts.hindSiliguri()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _sessionId = v;
                                  _subjectId = null;
                                  _chapterId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _subjectId,
                              decoration: InputDecoration(
                                labelText: 'বিষয়',
                                labelStyle: GoogleFonts.hindSiliguri(),
                                border: const OutlineInputBorder(),
                              ),
                              items: subjects
                                  .map(
                                    (s) => DropdownMenuItem<String>(
                                      value: s.id,
                                      child: Text(s.nameBn, style: GoogleFonts.hindSiliguri()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _subjectId = v;
                                  _chapterId = null;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _chapterId,
                              decoration: InputDecoration(
                                labelText: 'অধ্যায়',
                                labelStyle: GoogleFonts.hindSiliguri(),
                                border: const OutlineInputBorder(),
                              ),
                              items: chapters
                                  .map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(c.nameBn, style: GoogleFonts.hindSiliguri()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _chapterId = v);
                              },
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: (_chapterId == null || userAsync.value?.id == null)
                                    ? null
                                    : () {
                                        String? chapter;
                                        for (final c in chapters) {
                                          if (c.id == _chapterId) {
                                            chapter = c.nameBn;
                                            break;
                                          }
                                        }
                                        context.push(
                                          '/student/qbank/practice/${_chapterId!}'
                                          '?chapter=${Uri.encodeComponent(chapter ?? '')}',
                                        );
                                      },
                                icon: const Icon(Icons.bolt_outlined),
                                label: Text('Practice শুরু করুন', style: GoogleFonts.hindSiliguri()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tab,
                        tabs: const [
                          Tab(text: 'MCQ'),
                          Tab(text: 'CQ'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _StudentMcqList(chapterId: _chapterId!, userId: userAsync.value?.id),
                            _StudentCqList(chapterId: _chapterId!, userId: userAsync.value?.id),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Chapter load failed: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Subject load failed: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Session load failed: $e')),
      ),
    );
  }

  Future<void> _showBookmarksDialog(BuildContext context, String studentId) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('আমার Bookmarks', style: GoogleFonts.hindSiliguri()),
        content: SizedBox(
          width: 560,
          child: Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(qbankBookmarksProvider(studentId));
              return async.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(child: Text('কোনো বুকমার্ক নেই', style: GoogleFonts.hindSiliguri()));
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final b = items[i];
                      return ListTile(
                        dense: true,
                        title: Text('${b.questionType.toUpperCase()} · ${b.questionId}', style: GoogleFonts.nunito()),
                        subtitle: b.note == null ? null : Text(b.note!, style: GoogleFonts.hindSiliguri()),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'delete') {
                              await QBankRepository().removeBookmarkById(b.id);
                              ref.invalidate(qbankBookmarksProvider(studentId));
                            } else if (v == 'note') {
                              final noteCtl = TextEditingController(text: b.note ?? '');
                              final note = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('নোট', style: GoogleFonts.hindSiliguri()),
                                  content: TextField(controller: noteCtl, maxLines: 3),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, noteCtl.text),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              if (note != null) {
                                await QBankRepository().updateBookmarkNote(bookmarkId: b.id, note: note);
                                ref.invalidate(qbankBookmarksProvider(studentId));
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'note', child: Text('Edit note')),
                            PopupMenuItem(value: 'delete', child: Text('Remove')),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const Divider(height: 1),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<QbankSearchResult?> _openSearchSheet(
    BuildContext context, {
    String? initialSessionId,
    String? initialSubjectId,
  }) async {
    return showModalBottomSheet<QbankSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QbankSearchSheet(
        initialSessionId: initialSessionId,
        initialSubjectId: initialSubjectId,
      ),
    );
  }
}

class _QbankSearchSheet extends StatefulWidget {
  const _QbankSearchSheet({
    this.initialSessionId,
    this.initialSubjectId,
  });

  final String? initialSessionId;
  final String? initialSubjectId;

  @override
  State<_QbankSearchSheet> createState() => _QbankSearchSheetState();
}

class _QbankSearchSheetState extends State<_QbankSearchSheet> {
  final _repo = QBankRepository();
  final _queryCtl = TextEditingController();
  bool _loading = false;
  String? _sessionId;
  String? _subjectId;
  String? _type;
  List<QbankSession> _sessions = const [];
  List<QbankSubject> _subjects = const [];
  List<QbankSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _sessionId = widget.initialSessionId;
    _subjectId = widget.initialSubjectId;
    _loadScope();
  }

  @override
  void dispose() {
    _queryCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('প্রশ্ন খুঁজুন', style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: _queryCtl,
            decoration: InputDecoration(
              hintText: 'যেকোনো প্রশ্ন খুঁজুন...',
              hintStyle: GoogleFonts.hindSiliguri(),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'ধরন',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('সব')),
                    DropdownMenuItem<String?>(value: 'mcq', child: Text('MCQ')),
                    DropdownMenuItem<String?>(value: 'cq', child: Text('CQ')),
                  ],
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _sessionId,
                  decoration: const InputDecoration(labelText: 'Session', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ..._sessions.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) async {
                    setState(() {
                      _sessionId = v;
                      _subjectId = null;
                      _subjects = const [];
                    });
                    await _loadSubjects();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _subjectId,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ..._subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.nameBn))),
                  ],
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
                label: Text('Search', style: GoogleFonts.nunito()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('ফলাফল নেই', style: GoogleFonts.hindSiliguri()),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            title: Text(r.previewText, style: GoogleFonts.hindSiliguri(), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${r.questionType.toUpperCase()} · ${r.difficulty} · ${r.source ?? 'custom'}',
                              style: GoogleFonts.nunito(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, r),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _search() async {
    final q = _queryCtl.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final rows = await _repo.searchQuestions(
        q,
        sessionId: _sessionId,
        subjectId: _subjectId,
        type: _type,
        limit: 50,
      );
      if (!mounted) return;
      setState(() => _results = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadScope() async {
    final sessions = await _repo.getSessions();
    if (!mounted) return;
    setState(() => _sessions = sessions);
    await _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    if (_sessionId == null || _sessionId!.isEmpty) return;
    final subjects = await _repo.getSubjects(_sessionId!);
    if (!mounted) return;
    setState(() => _subjects = subjects);
  }
}

class QBankPracticeScreen extends ConsumerStatefulWidget {
  const QBankPracticeScreen({
    super.key,
    required this.chapterId,
    this.chapterName,
  });

  final String chapterId;
  final String? chapterName;

  @override
  ConsumerState<QBankPracticeScreen> createState() => _QBankPracticeScreenState();
}

class _QBankPracticeScreenState extends ConsumerState<QBankPracticeScreen> {
  final _repo = QBankRepository();
  final Stopwatch _quizWatch = Stopwatch();
  final Stopwatch _questionWatch = Stopwatch();
  bool _loading = false;
  List<QbankMcq> _questions = const [];
  int _current = 0;
  int _correct = 0;
  bool _answered = false;
  String? _selected;
  String? _sessionId;
  final List<QbankMcq> _wrong = [];
  int _count = 10;
  bool _started = false;
  String? _difficulty;
  String? _source;
  List<QbankPracticeSessionView> _history = const [];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final uid = user?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text('Practice Mode', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      ),
      body: uid == null
          ? Center(child: Text('লগইন প্রয়োজন', style: GoogleFonts.hindSiliguri()))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : !_started
                  ? _buildStart(uid)
                  : _current >= _questions.length
                      ? _buildSummary(uid)
                      : _buildQuestion(),
    );
  }

  Widget _buildStart(String uid) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.chapterName ?? 'অধ্যায় প্র্যাকটিস', style: GoogleFonts.hindSiliguri(fontSize: 18)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: 'কঠিনতা', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('সব')),
              DropdownMenuItem<String?>(value: 'easy', child: Text('সহজ')),
              DropdownMenuItem<String?>(value: 'medium', child: Text('মধ্যম')),
              DropdownMenuItem<String?>(value: 'hard', child: Text('কঠিন')),
            ],
            onChanged: (v) => setState(() => _difficulty = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _source,
            decoration: const InputDecoration(labelText: 'উৎস', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('সব')),
              DropdownMenuItem<String?>(value: 'board', child: Text('board')),
              DropdownMenuItem<String?>(value: 'practice', child: Text('practice')),
              DropdownMenuItem<String?>(value: 'custom', child: Text('custom')),
            ],
            onChanged: (v) => setState(() => _source = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _count,
            decoration: const InputDecoration(labelText: 'প্রশ্ন সংখ্যা', border: OutlineInputBorder()),
            items: const [10, 20, 30]
                .map((e) => DropdownMenuItem<int>(value: e, child: Text('$e')))
                .toList(),
            onChanged: (v) => setState(() => _count = v ?? 10),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _start(uid),
                icon: const Icon(Icons.play_arrow),
                label: Text('Practice শুরু', style: GoogleFonts.hindSiliguri()),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _loadHistory(uid),
                icon: const Icon(Icons.history),
                label: Text('History', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_history.isNotEmpty)
            ..._history.take(5).map(
                  (h) => Text(
                    '${h.startedAt.toLocal()} · ${h.correctAnswers}/${h.totalQuestions}',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_current];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('প্রশ্ন ${_current + 1}/${_questions.length}', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        Text(
          'সময়: ${_fmtDuration(_quizWatch.elapsed)} · এই প্রশ্ন: ${_fmtDuration(_questionWatch.elapsed)}',
          style: GoogleFonts.nunito(fontSize: 12),
        ),
        const SizedBox(height: 10),
        MixedContentRenderer(content: q.questionText),
        const SizedBox(height: 14),
        ...['A', 'B', 'C', 'D'].map((op) {
          final text = switch (op) {
            'A' => q.optionA,
            'B' => q.optionB,
            'C' => q.optionC,
            _ => q.optionD,
          };
          final selected = _selected == op;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !_answered,
            onTap: _answered ? null : () => setState(() => _selected = op),
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text('($op) $text', style: GoogleFonts.hindSiliguri()),
          );
        }),
        const SizedBox(height: 10),
        if (!_answered)
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _selected == null ? null : _submitCurrent,
                  child: Text('উত্তর দাও', style: GoogleFonts.hindSiliguri()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _skipCurrent,
                child: Text('Skip', style: GoogleFonts.nunito()),
              ),
            ],
          ),
        if (_answered) ...[
          Text(
            _selected == q.correctOption
                ? '✅ সঠিক!'
                : '❌ ভুল! সঠিক উত্তর: ${q.correctOption}',
            style: GoogleFonts.hindSiliguri(),
          ),
          if ((q.explanation ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('ব্যাখ্যা: ${q.explanation}', style: GoogleFonts.hindSiliguri()),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _next,
            child: Text(
              _current + 1 >= _questions.length ? 'Summary দেখুন' : 'পরের প্রশ্ন',
              style: GoogleFonts.hindSiliguri(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(String uid) {
    final wrongCount = _questions.length - _correct;
    final score = _questions.isEmpty ? 0 : ((_correct * 100) / _questions.length).round();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎉 Practice শেষ', style: GoogleFonts.hindSiliguri(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('মোট: ${_questions.length} | সঠিক: $_correct | ভুল: $wrongCount', style: GoogleFonts.hindSiliguri()),
          Text('স্কোর: $score%', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_wrong.isNotEmpty)
            Text('ভুল প্রশ্ন: ${_wrong.length} টি', style: GoogleFonts.hindSiliguri()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _started = false;
                    _questions = const [];
                    _current = 0;
                    _correct = 0;
                    _selected = null;
                    _answered = false;
                    _wrong.clear();
                  });
                },
                child: Text('আবার Practice', style: GoogleFonts.hindSiliguri()),
              ),
              FilledButton(
                onPressed: _wrong.isEmpty ? null : () => _bookmarkWrong(uid),
                child: Text('ভুলগুলো Bookmark', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _start(String uid) async {
    setState(() => _loading = true);
    try {
      final qs = await _repo.getPracticeQuestions(
        chapterId: widget.chapterId,
        count: _count,
        difficulty: _difficulty,
        source: _source,
      );
      final sid = await _repo.startPracticeSession(
        studentId: uid,
        chapterId: widget.chapterId,
        questionType: 'mcq',
        totalQuestions: qs.length,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _questions = qs;
        _started = true;
        _current = 0;
        _correct = 0;
        _selected = null;
        _answered = false;
        _wrong.clear();
      });
      _quizWatch
        ..reset()
        ..start();
      _questionWatch
        ..reset()
        ..start();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCurrent() async {
    final q = _questions[_current];
    final selected = _selected;
    if (selected == null || _sessionId == null) return;
    final isCorrect = selected == q.correctOption;
    if (isCorrect) {
      _correct++;
    } else {
      _wrong.add(q);
    }
    await _repo.savePracticeAnswer(
      sessionId: _sessionId!,
      questionId: q.id,
      questionType: 'mcq',
      selectedOption: selected,
      isCorrect: isCorrect,
    );
    _questionWatch.stop();
    setState(() => _answered = true);
  }

  Future<void> _next() async {
    if (_current + 1 >= _questions.length) {
      if (_sessionId != null) {
        await _repo.completePracticeSession(
          sessionId: _sessionId!,
          correctAnswers: _correct,
        );
      }
      _quizWatch.stop();
    }
    setState(() {
      _current++;
      _selected = null;
      _answered = false;
    });
    _questionWatch
      ..reset()
      ..start();
  }

  Future<void> _skipCurrent() async {
    if (_sessionId == null) return;
    final q = _questions[_current];
    await _repo.savePracticeAnswer(
      sessionId: _sessionId!,
      questionId: q.id,
      questionType: 'mcq',
      selectedOption: null,
      isCorrect: false,
    );
    _wrong.add(q);
    await _next();
  }

  Future<void> _bookmarkWrong(String uid) async {
    for (final q in _wrong) {
      await _repo.toggleBookmark(
        studentId: uid,
        questionType: 'mcq',
        questionId: q.id,
      );
    }
    if (!mounted) return;
    ref.invalidate(qbankBookmarksProvider(uid));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_wrong.length} টি প্রশ্ন bookmark করা হয়েছে', style: GoogleFonts.hindSiliguri())),
    );
  }

  Future<void> _loadHistory(String uid) async {
    final rows = await _repo.listPracticeHistory(
      studentId: uid,
      chapterId: widget.chapterId,
      limit: 10,
    );
    if (!mounted) return;
    setState(() => _history = rows);
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StudentMcqList extends ConsumerStatefulWidget {
  const _StudentMcqList({required this.chapterId, required this.userId});
  final String chapterId;
  final String? userId;

  @override
  ConsumerState<_StudentMcqList> createState() => _StudentMcqListState();
}

class _StudentMcqListState extends ConsumerState<_StudentMcqList> {
  final Set<String> _revealed = <String>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      qbankMcqQuestionsProvider(QbankQuestionQuery(chapterId: widget.chapterId)),
    );
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text('কোনো MCQ নেই', style: GoogleFonts.hindSiliguri()));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final q = items[i];
            final show = _revealed.contains(q.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MixedContentRenderer(content: q.questionText),
                    if ((q.imageUrl ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Image.network(q.imageUrl!, height: 140),
                    ],
                    const SizedBox(height: 8),
                    Text('A) ${q.optionA}', style: GoogleFonts.hindSiliguri()),
                    Text('B) ${q.optionB}', style: GoogleFonts.hindSiliguri()),
                    Text('C) ${q.optionC}', style: GoogleFonts.hindSiliguri()),
                    Text('D) ${q.optionD}', style: GoogleFonts.hindSiliguri()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            if (show) {
                              _revealed.remove(q.id);
                            } else {
                              _revealed.add(q.id);
                            }
                          }),
                          child: Text(show ? 'উত্তর লুকান' : 'উত্তর দেখাও', style: GoogleFonts.hindSiliguri()),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Bookmark',
                          onPressed: widget.userId == null
                              ? null
                              : () async {
                                  await QBankRepository().toggleBookmark(
                                    studentId: widget.userId!,
                                    questionType: 'mcq',
                                    questionId: q.id,
                                  );
                                  ref.invalidate(qbankBookmarksProvider(widget.userId!));
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text('Bookmark updated', style: GoogleFonts.nunito())),
                                );
                                },
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
                      ],
                    ),
                    if (show) ...[
                      const Divider(),
                      Text('সঠিক উত্তর: ${q.correctOption}', style: GoogleFonts.hindSiliguri()),
                      if ((q.explanation ?? '').trim().isNotEmpty)
                        MixedContentRenderer(content: q.explanation!),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('MCQ load failed: $e')),
    );
  }
}

class _StudentCqList extends ConsumerStatefulWidget {
  const _StudentCqList({required this.chapterId, required this.userId});
  final String chapterId;
  final String? userId;

  @override
  ConsumerState<_StudentCqList> createState() => _StudentCqListState();
}

class _StudentCqListState extends ConsumerState<_StudentCqList> {
  final Set<String> _ga = <String>{};
  final Set<String> _gha = <String>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      qbankCqQuestionsProvider(QbankQuestionQuery(chapterId: widget.chapterId)),
    );
    return async.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text('কোনো CQ নেই', style: GoogleFonts.hindSiliguri()));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final q = items[i];
            final showGa = _ga.contains(q.id);
            final showGha = _gha.contains(q.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('উদ্দীপক', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                    MixedContentRenderer(content: q.stemText),
                    const SizedBox(height: 8),
                    Text('গ (${q.gaMarks}) ${q.gaText}', style: GoogleFonts.hindSiliguri()),
                    TextButton(
                      onPressed: () => setState(() => showGa ? _ga.remove(q.id) : _ga.add(q.id)),
                      child: Text(showGa ? 'গ উত্তর লুকান' : 'গ উত্তর দেখাও', style: GoogleFonts.hindSiliguri()),
                    ),
                    if (showGa && (q.gaAnswer ?? '').trim().isNotEmpty)
                      MixedContentRenderer(content: q.gaAnswer!),
                    const SizedBox(height: 8),
                    Text('ঘ (${q.ghaMarks}) ${q.ghaText}', style: GoogleFonts.hindSiliguri()),
                    TextButton(
                      onPressed: () => setState(() => showGha ? _gha.remove(q.id) : _gha.add(q.id)),
                      child: Text(showGha ? 'ঘ উত্তর লুকান' : 'ঘ উত্তর দেখাও', style: GoogleFonts.hindSiliguri()),
                    ),
                    if (showGha && (q.ghaAnswer ?? '').trim().isNotEmpty)
                      MixedContentRenderer(content: q.ghaAnswer!),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Bookmark',
                        onPressed: widget.userId == null
                            ? null
                            : () async {
                                await QBankRepository().toggleBookmark(
                                  studentId: widget.userId!,
                                  questionType: 'cq',
                                  questionId: q.id,
                                );
                                ref.invalidate(qbankBookmarksProvider(widget.userId!));
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text('Bookmark updated', style: GoogleFonts.nunito())),
                                );
                              },
                        icon: const Icon(Icons.bookmark_add_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('CQ load failed: $e')),
    );
  }
}
