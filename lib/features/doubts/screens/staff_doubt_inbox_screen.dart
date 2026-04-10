import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/doubt_thread_model.dart';
import '../../../shared/models/user_model.dart';
import '../../admin/widgets/admin_responsive_scaffold.dart';
import '../../teacher/widgets/teacher_drawer.dart';
import '../repositories/doubt_repository.dart';

/// Admin + teacher: all doubt threads (newest first), tap to open chat.
class StaffDoubtInboxScreen extends StatefulWidget {
  const StaffDoubtInboxScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<StaffDoubtInboxScreen> createState() => _StaffDoubtInboxScreenState();
}

class _StaffDoubtInboxScreenState extends State<StaffDoubtInboxScreen> {
  late Future<List<DoubtThreadModel>> _future;
  final _repo = DoubtRepository();
  Map<String, UserModel> _users = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DoubtThreadModel>> _load() async {
    final list = await _repo.listAllForStaff();
    final ids = list.map((e) => e.studentId).toSet();
    _users = await _repo.loadUsersByIds(ids);
    return list;
  }

  String _studentLabel(String studentId) {
    final u = _users[studentId];
    if (u == null) return studentId;
    return u.fullNameBn;
  }

  @override
  Widget build(BuildContext context) {
    final prefix = widget.isAdmin ? '/admin/doubts' : '/teacher/doubts';

    final body = FutureBuilder<List<DoubtThreadModel>>(
      future: _future,
      builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}', style: GoogleFonts.hindSiliguri()));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Text('কোনো সন্দেহ নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = list[i];
                final preview = d.problemDescription.length > 80
                    ? '${d.problemDescription.substring(0, 80)}…'
                    : d.problemDescription;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: d.status == DoubtStatus.solved
                        ? Colors.green.withValues(alpha: 0.2)
                        : context.themePrimary.withValues(alpha: 0.15),
                    child: Icon(
                      d.status == DoubtStatus.solved ? Icons.check_circle_outline : Icons.help_outline,
                      color: d.status == DoubtStatus.solved ? Colors.green : context.themePrimary,
                    ),
                  ),
                  title: Text(
                    _studentLabel(d.studentId),
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('$prefix/${d.id}'),
                );
              },
            ),
          );
      },
    );

    if (widget.isAdmin) {
      return AdminResponsiveScaffold(
        title: Text(
          'সন্দেহ সমাধান',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
        body: body,
      );
    }

    return Scaffold(
      drawer: const TeacherDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text(
          'সন্দেহ সমাধান',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: body,
    );
  }
}
