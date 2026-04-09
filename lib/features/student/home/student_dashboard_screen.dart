import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/payment_due_model.dart';
import '../../admin/payments/repositories/payment_repository.dart';
import '../../admin/students/repositories/student_repository.dart';

/// Student home: greeting, quick stats, shortcuts.
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late Future<_DashData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashData> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final student = await StudentRepository().getStudentById(uid);
    final month = DateTime.now();
    final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final att = await StudentRepository().getStudentAttendanceSummary(uid, ym);
    final dues = await PaymentRepository().getDues(studentId: uid);
    final openDues = dues.where((d) => d.status == DueStatus.due).length;
    return _DashData(
      name: student.fullNameBn,
      attendancePct: att['percentage'] as double?,
      openDues: openDues,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('হোম', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'হ্যালো, ${d.name}!',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'উপস্থিতি',
                      value: d.attendancePct == null
                          ? '—'
                          : '${d.attendancePct!.toStringAsFixed(0)}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'খোলা বকেয়া',
                      value: '${d.openDues}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'দ্রুত লিংক',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: Text('কোর্স', style: GoogleFonts.hindSiliguri()),
                    onPressed: () => context.push('/student/courses'),
                  ),
                  ActionChip(
                    label: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
                    onPressed: () => context.push('/student/exams'),
                  ),
                  ActionChip(
                    label: Text('পেমেন্ট', style: GoogleFonts.hindSiliguri()),
                    onPressed: () => context.push('/student/payments'),
                  ),
                  ActionChip(
                    label: Text('গ্রুপ', style: GoogleFonts.hindSiliguri()),
                    onPressed: () => context.push('/student/community'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashData {
  const _DashData({
    required this.name,
    required this.attendancePct,
    required this.openDues,
  });

  final String name;
  final double? attendancePct;
  final int openDues;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.hindSiliguri(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
