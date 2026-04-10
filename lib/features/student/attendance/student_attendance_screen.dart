import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase_client.dart';
import '../../admin/students/repositories/student_repository.dart';
import '../widgets/student_drawer.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final month = DateTime.now();
    final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return StudentRepository().getStudentAttendanceSummary(uid, ym);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('উপস্থিতি', style: GoogleFonts.hindSiliguri()),
        actions: const [AppBarDrawerAction()],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final m = snap.data!;
          final pct = m['percentage'] as double?;
          final total = m['total_sessions'] as int? ?? 0;
          final present = m['present'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'এই মাস',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'মোট সেশন: $total',
                  style: GoogleFonts.hindSiliguri(),
                ),
                Text(
                  'উপস্থিত: $present',
                  style: GoogleFonts.hindSiliguri(),
                ),
                const SizedBox(height: 8),
                Text(
                  pct == null
                      ? 'হার হিসাব করা যায়নি'
                      : 'হার: ${pct.toStringAsFixed(1)}%',
                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
