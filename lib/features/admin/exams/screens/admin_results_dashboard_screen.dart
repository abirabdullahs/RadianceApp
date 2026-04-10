import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/supabase_client.dart';
import '../../../results/repositories/result_repository.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../services/result_calculator.dart';

class AdminResultsDashboardScreen extends StatefulWidget {
  const AdminResultsDashboardScreen({super.key});

  @override
  State<AdminResultsDashboardScreen> createState() => _AdminResultsDashboardScreenState();
}

class _AdminResultsDashboardScreenState extends State<AdminResultsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _future = _loadExams();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadExams() async {
    final rows = await supabaseClient
        .from('exams')
        .select('id,title,exam_mode,status,start_time,end_time,total_marks,pass_marks')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _reload() async {
    setState(() => _future = _loadExams());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text('ফলাফল ব্যবস্থাপনা', style: GoogleFonts.hindSiliguri()),
      bottom: TabBar(
        controller: _tab,
        tabs: const [
          Tab(text: 'Online'),
          Tab(text: 'Offline'),
          Tab(text: 'সব'),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final exams = snap.data!;
          return TabBarView(
            controller: _tab,
            children: [
              _ExamList(
                exams: exams.where((e) => e['exam_mode'] == 'online').toList(),
                onReload: _reload,
              ),
              _ExamList(
                exams: exams.where((e) => e['exam_mode'] == 'offline').toList(),
                onReload: _reload,
              ),
              _ExamList(exams: exams, onReload: _reload),
            ],
          );
        },
      ),
    );
  }
}

class _ExamList extends StatelessWidget {
  const _ExamList({required this.exams, required this.onReload});

  final List<Map<String, dynamic>> exams;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return Center(child: Text('কোনো পরীক্ষা নেই', style: GoogleFonts.hindSiliguri()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: exams.length,
      itemBuilder: (context, i) => _ExamResultCard(exam: exams[i], onReload: onReload),
    );
  }
}

class _ExamResultCard extends StatefulWidget {
  const _ExamResultCard({required this.exam, required this.onReload});

  final Map<String, dynamic> exam;
  final Future<void> Function() onReload;

  @override
  State<_ExamResultCard> createState() => _ExamResultCardState();
}

class _ExamResultCardState extends State<_ExamResultCard> {
  final _repo = ResultRepository();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final id = exam['id'] as String;
    final title = exam['title'] as String? ?? 'Exam';
    final mode = (exam['exam_mode'] as String?) ?? 'online';
    final isPublished = (exam['status'] as String?) == 'result_published';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${mode == 'online' ? '🌐 Online' : '📋 Offline'} · ${isPublished ? 'Published' : 'Unpublished'}',
              style: GoogleFonts.nunito(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _preview(context, id, title),
                  child: Text('Preview', style: GoogleFonts.hindSiliguri()),
                ),
                FilledButton(
                  onPressed: _busy || isPublished
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            if (mode == 'online') {
                              await ResultCalculator().calculateResults(id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'অফলাইন পরীক্ষার রেজাল্ট exam detail থেকে আপলোড করুন।',
                                    style: GoogleFonts.hindSiliguri(),
                                  ),
                                ),
                              );
                            }
                            await widget.onReload();
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: Text('Publish', style: GoogleFonts.hindSiliguri()),
                ),
                OutlinedButton(
                  onPressed: () => _exportCsv(context, id, title),
                  child: Text('CSV', style: GoogleFonts.hindSiliguri()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _preview(BuildContext context, String examId, String title) async {
    final rows = await _repo.listAdminExamResults(examId);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title · ফলাফল প্রিভিউ', style: GoogleFonts.hindSiliguri()),
        content: SizedBox(
          width: 680,
          child: rows.isEmpty
              ? Text('কোনো ফলাফল নেই', style: GoogleFonts.hindSiliguri())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length > 20 ? 20 : rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final u = Map<String, dynamic>.from(r['users'] as Map? ?? const {});
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${r['rank'] ?? '-'} · ${u['full_name_bn'] ?? 'Student'}',
                        style: GoogleFonts.hindSiliguri(),
                      ),
                      subtitle: Text(
                        'Score ${r['score']}/${r['total_marks']} · Grade ${r['grade'] ?? '-'}',
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
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

  Future<void> _exportCsv(BuildContext context, String examId, String title) async {
    final rows = await _repo.listAdminExamResults(examId);
    final csvRows = <String>[
      'rank,student_id,name,score,total_marks,percentage,grade,is_passed',
    ];
    for (final r in rows) {
      final u = Map<String, dynamic>.from(r['users'] as Map? ?? const {});
      csvRows.add(
        '${r['rank'] ?? ''},${u['student_id'] ?? ''},"${(u['full_name_bn'] ?? '').toString().replaceAll('"', '""')}",'
        '${r['score'] ?? ''},${r['total_marks'] ?? ''},${r['percentage'] ?? ''},${r['grade'] ?? ''},${r['is_passed'] ?? ''}',
      );
    }
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save result CSV',
      fileName: 'result_${title.replaceAll(' ', '_')}.csv',
      bytes: utf8.encode(csvRows.join('\n')),
    );
    if (!context.mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV সংরক্ষণ হয়েছে', style: GoogleFonts.hindSiliguri())),
    );
  }
}
