import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/models/result_model.dart';
import '../../admin/students/repositories/student_repository.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  late Future<List<ResultModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ResultModel>> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    return StudentRepository().getStudentResults(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ফলাফল', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<ResultModel>>(
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
              return ListTile(
                title: Text(
                  '${r.score.toStringAsFixed(0)} / ${r.totalMarks.toStringAsFixed(0)}',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'গ্রেড: ${r.grade ?? "—"} · র‍্যাঙ্ক: ${r.rank ?? "—"}',
                  style: GoogleFonts.hindSiliguri(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
