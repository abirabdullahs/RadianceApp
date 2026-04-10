import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../../results/repositories/result_repository.dart';
import '../widgets/student_drawer.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  final _repo = ResultRepository();
  final DateFormat _dtFormat = DateFormat('dd MMM yyyy, hh:mm a');
  String _tab = 'all';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return _repo.getStudentResults(
      studentId: supabaseClient.auth.currentUser!.id,
      examType: _tab == 'all' ? null : _tab,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('আমার ফলাফল', style: GoogleFonts.hindSiliguri()),
        actions: const [AppBarDrawerAction()],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(child: Text('কোনো ফলাফল নেই', style: GoogleFonts.hindSiliguri()));
          }

          final avg = list
                  .map((e) => (e['percentage'] as num?)?.toDouble() ?? 0)
                  .fold<double>(0, (a, b) => a + b) /
              list.length;
          final passed = list.where((e) => e['is_passed'] == true).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _chip('all', 'সব'),
                    _chip('online', '🌐 Online'),
                    _chip('offline', '📋 Offline'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  child: ListTile(
                    title: Text('গড়: ${avg.toStringAsFixed(1)}%', style: GoogleFonts.hindSiliguri()),
                    subtitle: Text(
                      'মোট ${list.length} টি · পাস $passed/${list.length}',
                      style: GoogleFonts.nunito(fontSize: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final exam = Map<String, dynamic>.from(r['exams'] as Map? ?? const {});
                    final title = exam['title']?.toString() ?? 'Exam';
                    final mode = (r['exam_type'] ?? exam['exam_mode'] ?? '-').toString().toUpperCase();
                    final publishedAt = _parseDt(r['published_at']);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${r['score']} / ${r['total_marks']} · Rank ${r['rank'] ?? '-'} · $mode'
                          '${publishedAt == null ? '' : '\nPublished: ${_dtFormat.format(publishedAt.toLocal())}'}',
                          style: GoogleFonts.nunito(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final examId = (r['exam_id'] as String?) ?? '';
                          if (examId.isEmpty) return;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _ResultDetailScreen(examId: examId, examTitle: title),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String value, String label) {
    return ChoiceChip(
      selected: _tab == value,
      label: Text(label, style: GoogleFonts.hindSiliguri()),
      onSelected: (_) {
        setState(() {
          _tab = value;
          _future = _load();
        });
      },
    );
  }

  DateTime? _parseDt(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _ResultDetailScreen extends StatefulWidget {
  const _ResultDetailScreen({required this.examId, required this.examTitle});

  final String examId;
  final String examTitle;

  @override
  State<_ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<_ResultDetailScreen> {
  final _repo = ResultRepository();
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getStudentResultDetail(
      examId: widget.examId,
      studentId: supabaseClient.auth.currentUser!.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ((ModalRoute.of(context)?.settings.arguments as Map?)?['exam_type'] ?? '').toString() == 'online';
    return Scaffold(
      appBar: AppBar(title: Text(widget.examTitle, style: GoogleFonts.hindSiliguri())),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final r = snap.data;
          if (r == null) return Center(child: Text('ফলাফল পাওয়া যায়নি', style: GoogleFonts.hindSiliguri()));
          final exam = Map<String, dynamic>.from(r['exams'] as Map? ?? const {});
          final online = (r['exam_type'] ?? exam['exam_mode']) == 'online' || isOnline;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  title: Text(
                    '${r['score']} / ${r['total_marks']}',
                    style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Grade ${r['grade'] ?? '-'} · Rank #${r['rank'] ?? '-'}',
                    style: GoogleFonts.hindSiliguri(),
                  ),
                ),
              ),
              if (online)
                Card(
                  child: ListTile(
                    title: Text(
                      'সঠিক ${r['total_correct'] ?? 0} · ভুল ${r['total_wrong'] ?? 0} · বাদ ${r['total_skipped'] ?? 0}',
                      style: GoogleFonts.hindSiliguri(),
                    ),
                    subtitle: Text(
                      'Negative ${r['negative_deduction'] ?? 0} · Time ${r['time_taken_seconds'] ?? '-'}s',
                      style: GoogleFonts.nunito(fontSize: 12),
                    ),
                  ),
                ),
              if ((r['remarks'] as String?)?.trim().isNotEmpty == true)
                Card(
                  child: ListTile(
                    title: Text('মন্তব্য', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                    subtitle: Text('${r['remarks']}', style: GoogleFonts.hindSiliguri()),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ExamLeaderboardScreen(
                        examId: widget.examId,
                        examTitle: widget.examTitle,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.leaderboard_outlined),
                label: Text('Leaderboard', style: GoogleFonts.hindSiliguri()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExamLeaderboardScreen extends StatefulWidget {
  const _ExamLeaderboardScreen({required this.examId, required this.examTitle});

  final String examId;
  final String examTitle;

  @override
  State<_ExamLeaderboardScreen> createState() => _ExamLeaderboardScreenState();
}

class _ExamLeaderboardScreenState extends State<_ExamLeaderboardScreen> {
  final _repo = ResultRepository();
  final _controller = ScrollController();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getLeaderboard(widget.examId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = supabaseClient.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.examTitle, style: GoogleFonts.hindSiliguri())),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) return Center(child: Text('কোনো রেজাল্ট নেই', style: GoogleFonts.hindSiliguri()));
          final myIndex = rows.indexWhere((e) => e['student_id'] == me);
          if (myIndex >= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_controller.hasClients) {
                _controller.animateTo(
                  (myIndex * 72.0).clamp(0, _controller.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                );
              }
            });
          }
          return ListView.builder(
            controller: _controller,
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              final u = Map<String, dynamic>.from(row['users'] as Map? ?? const {});
              final isMe = row['student_id'] == me;
              return ListTile(
                tileColor: isMe ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
                leading: CircleAvatar(child: Text('${row['rank'] ?? '-'}')),
                title: Text(
                  '${u['full_name_bn'] ?? 'Student'} (${u['student_id'] ?? '-'})${isMe ? ' · তুমি' : ''}',
                  style: GoogleFonts.hindSiliguri(),
                ),
                subtitle: Text(
                  'Score ${row['score']} / ${row['total_marks']} · ${row['percentage'] ?? 0}%',
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
