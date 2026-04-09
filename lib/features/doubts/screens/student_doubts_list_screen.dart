import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/notification_app_bar_action.dart';
import '../../../shared/models/doubt_thread_model.dart';
import '../repositories/doubt_repository.dart';
import '../../student/widgets/student_drawer.dart';

/// Student: own doubts (newest first); FAB for new doubt; optional purge prompt.
class StudentDoubtsListScreen extends StatefulWidget {
  const StudentDoubtsListScreen({super.key});

  @override
  State<StudentDoubtsListScreen> createState() => _StudentDoubtsListScreenState();
}

class _StudentDoubtsListScreenState extends State<StudentDoubtsListScreen> {
  late Future<List<DoubtThreadModel>> _future;
  final _repo = DoubtRepository();

  @override
  void initState() {
    super.initState();
    _future = _repo.listMyDoubts();
  }

  Future<void> _confirmPurge(DoubtThreadModel d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('চ্যাট মুছবেন?', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
        content: Text(
          'এই সন্দেহের মেসেজগুলো সার্ভার থেকে মুছে যাবে। থ্রেড থাকবে।',
          style: GoogleFonts.hindSiliguri(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('না', style: GoogleFonts.hindSiliguri()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('হ্যাঁ, মুছুন', style: GoogleFonts.hindSiliguri()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.purgeMessages(d.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('মেসেজ মুছে ফেলা হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
      setState(() => _future = _repo.listMyDoubts());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ব্যর্থ: $e', style: GoogleFonts.hindSiliguri())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('সন্দেহ সমাধান', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        actions: const [NotificationAppBarAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/student/doubts/new'),
        icon: const Icon(Icons.add),
        label: Text('নতুন সন্দেহ', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<DoubtThreadModel>>(
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'কোনো সন্দেহ নেই। নিচের বাটনে নতুন সন্দেহ জমা দিন।',
                  style: GoogleFonts.hindSiliguri(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _repo.listMyDoubts());
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = list[i];
                final preview = d.problemDescription.length > 100
                    ? '${d.problemDescription.substring(0, 100)}…'
                    : d.problemDescription;
                return ListTile(
                  leading: Icon(
                    d.status == DoubtStatus.solved ? Icons.check_circle : Icons.help_outline,
                    color: d.status == DoubtStatus.solved ? Colors.green : context.themePrimary,
                  ),
                  title: Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    d.status == DoubtStatus.solved ? 'সমাধান হয়েছে' : 'খোলা',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'purge') _confirmPurge(d);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'purge',
                        child: Text('চ্যাট মুছুন', style: GoogleFonts.hindSiliguri()),
                      ),
                    ],
                  ),
                  onTap: () => context.push('/student/doubts/${d.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
