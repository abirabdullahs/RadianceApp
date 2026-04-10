import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_client.dart';
import '../widgets/student_drawer.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final DateFormat _dtFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final rows = await supabaseClient
        .from('results')
        .select('score,total_marks,rank,grade,percentage,published_at,exam_id,exams(id,title,status,exam_mode,start_time)')
        .eq('student_id', uid)
        .order('published_at', ascending: false);
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('ফলাফল', style: GoogleFonts.hindSiliguri()),
        actions: const [AppBarDrawerAction()],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Text('কোনো ফলাফল নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              final exam = Map<String, dynamic>.from(r['exams'] as Map? ?? const {});
              final title = (exam['title'] as String?) ?? 'Exam';
              final mode = (exam['exam_mode'] as String?) ?? '-';
              final publishedAt = _parseDt(r['published_at']);
              return ListTile(
                title: Text(title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${r['score']} / ${r['total_marks']} · Rank ${r['rank'] ?? '-'} · ${mode.toUpperCase()}'
                  '${publishedAt == null ? '' : '\nPublished: ${_dtFormat.format(publishedAt.toLocal())}'}',
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                trailing: const Icon(Icons.leaderboard_outlined),
                onTap: () {
                  final examId = (r['exam_id'] as String?) ?? '';
                  if (examId.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ExamLeaderboardScreen(
                        examId: examId,
                        examTitle: title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  DateTime? _parseDt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _ExamLeaderboardScreen extends StatefulWidget {
  const _ExamLeaderboardScreen({
    required this.examId,
    required this.examTitle,
  });

  final String examId;
  final String examTitle;

  @override
  State<_ExamLeaderboardScreen> createState() => _ExamLeaderboardScreenState();
}

class _ExamLeaderboardScreenState extends State<_ExamLeaderboardScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await supabaseClient
        .from('results')
        .select('student_id,score,total_marks,percentage,grade,rank,users(full_name_bn,student_id)')
        .eq('exam_id', widget.examId)
        .order('rank', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = supabaseClient.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examTitle, style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(child: Text('কোনো রেজাল্ট নেই', style: GoogleFonts.hindSiliguri()));
          }
          final myRow = rows.cast<Map<String, dynamic>?>().firstWhere(
                (e) => e?['student_id'] == me,
                orElse: () => null,
              );
          return Column(
            children: [
              if (myRow != null)
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text('আপনার অবস্থান: #${myRow['rank'] ?? '-'}', style: GoogleFonts.hindSiliguri()),
                    subtitle: Text(
                      'Score ${myRow['score']} / ${myRow['total_marks']} · Grade ${myRow['grade'] ?? '-'}',
                      style: GoogleFonts.nunito(fontSize: 12),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    final u = Map<String, dynamic>.from(row['users'] as Map? ?? const {});
                    final isMe = row['student_id'] == me;
                    return ListTile(
                      tileColor: isMe ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
                      leading: CircleAvatar(child: Text('${row['rank'] ?? '-'}')),
                      title: Text(
                        '${u['full_name_bn'] ?? 'Student'} (${u['student_id'] ?? '-'})',
                        style: GoogleFonts.hindSiliguri(),
                      ),
                      subtitle: Text(
                        'Score ${row['score']} / ${row['total_marks']} · ${row['percentage'] ?? 0}%',
                        style: GoogleFonts.nunito(fontSize: 12),
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
}
