import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/models/exam_model.dart';
import '../../widgets/student_drawer.dart';
import '../repositories/student_exam_repository.dart';

final _studentExamsProvider =
    FutureProvider.autoDispose<List<ExamModel>>((ref) async {
  return StudentExamRepository().listExamsForCurrentStudent();
});

class StudentExamsScreen extends ConsumerWidget {
  const StudentExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_studentExamsProvider);

    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
      ),
      body: async.when(
        data: (exams) {
          if (exams.isEmpty) {
            return Center(
              child: Text('কোনো পরীক্ষা নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_studentExamsProvider);
              await ref.read(_studentExamsProvider.future);
            },
            child: ListView.builder(
              itemCount: exams.length,
              itemBuilder: (context, i) {
                final e = exams[i];
                return ListTile(
                  title: Text(e.title, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(
                    e.status,
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => context.push('/student/exams/${e.id}/take'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
