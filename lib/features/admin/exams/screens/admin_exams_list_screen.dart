import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/exam_model.dart';
import '../repositories/exam_repository.dart';

final _adminExamsListProvider =
    FutureProvider.autoDispose<List<ExamModel>>((ref) async {
  return ExamRepository().listExams();
});

class AdminExamsScreen extends ConsumerStatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  ConsumerState<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends ConsumerState<AdminExamsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminExamsListProvider);

    return AdminResponsiveScaffold(
      title: Text('পরীক্ষা', style: GoogleFonts.hindSiliguri()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/exams/new'),
        backgroundColor: context.themePrimary,
        icon: const Icon(Icons.add),
        label: Text('নতুন পরীক্ষা', style: GoogleFonts.hindSiliguri()),
      ),
      body: async.when(
        data: (exams) {
          final filtered = exams.where((e) {
            switch (_filter) {
              case 'online':
                return e.examMode == 'online';
              case 'offline':
                return e.examMode == 'offline';
              case 'live':
                return e.status == 'live';
              default:
                return true;
            }
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text('এই ফিল্টারে কোনো পরীক্ষা নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _chip('all', 'সব'),
                    _chip('online', 'Online'),
                    _chip('offline', 'Offline'),
                    _chip('live', 'Live'),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_adminExamsListProvider);
                    await ref.read(_adminExamsListProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      final isOffline = e.examMode == 'offline';
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(e.title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${isOffline ? "📋 OFFLINE" : "🌐 ONLINE"} · ${e.status.toUpperCase()}'
                            '${isOffline ? "" : " · ${e.durationMinutes} মি."}',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/admin/exams/${e.id}'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _chip(String value, String label) {
    return ChoiceChip(
      selected: _filter == value,
      label: Text(label, style: GoogleFonts.hindSiliguri()),
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}
