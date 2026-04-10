import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
        actions: const [AppBarDrawerAction()],
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
                final isOffline = e.examMode == 'offline';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    title: Text(e.title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${e.examMode.toUpperCase()} · ${e.status}',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          if (isOffline && (e.venue?.trim().isNotEmpty ?? false))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Venue: ${e.venue}',
                                style: GoogleFonts.nunito(fontSize: 12),
                              ),
                            ),
                          if ((e.description?.trim().isNotEmpty ?? false))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                e.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.hindSiliguri(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 15),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _scheduleText(e),
                                  style: GoogleFonts.hindSiliguri(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: Icon(isOffline ? Icons.event_note_outlined : Icons.play_arrow),
                    onTap: () {
                      if (isOffline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'অফলাইন পরীক্ষা: ${_scheduleText(e)}',
                              style: GoogleFonts.hindSiliguri(),
                            ),
                          ),
                        );
                        return;
                      }
                      context.push('/student/exams/${e.id}/take');
                    },
                  ),
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

  String _scheduleText(ExamModel exam) {
    final start = exam.startTime;
    final end = exam.endTime;
    final f = DateFormat('dd MMM yyyy, hh:mm a');
    if (start == null && end == null) return 'সময়সূচী পরে জানানো হবে';
    if (start != null && end != null) {
      return '${f.format(start.toLocal())} - ${f.format(end.toLocal())}';
    }
    return f.format((start ?? end!).toLocal());
  }
}
