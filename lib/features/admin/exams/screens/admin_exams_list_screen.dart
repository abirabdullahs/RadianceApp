import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_drawer.dart';
import '../../../../shared/models/exam_model.dart';
import '../repositories/exam_repository.dart';

final _adminExamsListProvider =
    FutureProvider.autoDispose<List<ExamModel>>((ref) async {
  return ExamRepository().listExams();
});

class AdminExamsScreen extends ConsumerWidget {
  const AdminExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminExamsListProvider);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/exams/new'),
        backgroundColor: context.themePrimary,
        icon: const Icon(Icons.add),
        label: Text('নতুন পরীক্ষা', style: GoogleFonts.hindSiliguri()),
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
              ref.invalidate(_adminExamsListProvider);
              await ref.read(_adminExamsListProvider.future);
            },
            child: ListView.builder(
              itemCount: exams.length,
              itemBuilder: (context, i) {
                final e = exams[i];
                return ListTile(
                  title: Text(e.title, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(
                    '${e.status} · ${e.durationMinutes} মি.',
                    style: GoogleFonts.nunito(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/admin/exams/${e.id}'),
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
