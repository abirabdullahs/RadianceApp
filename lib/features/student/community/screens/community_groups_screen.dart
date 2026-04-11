import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/widgets/notification_app_bar_action.dart';
import '../../widgets/student_drawer.dart';
import '../repositories/community_repository.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunityRepository().listGroupsForCurrentStudentWithUnread();
  }

  Future<void> _reload() async {
    setState(() {
      _future = CommunityRepository().listGroupsForCurrentStudentWithUnread();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StudentDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('গ্রুপ চ্যাট', style: GoogleFonts.hindSiliguri()),
        actions: const [AppBarDrawerAction(), NotificationAppBarAction()],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('লোড করা যায়নি: ${snap.error}'),
                  ),
                ],
              );
            }
            final groups = snap.data ?? [];
            if (groups.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'সক্রিয় কোর্সে নথিভুক্ত নন বা কোর্স চ্যাট এখনো তৈরি হয়নি।\nকোর্সে ভর্তি হলে গ্রুপে স্বয়ংক্রিয় সদস্য হবেন।',
                        style: GoogleFonts.hindSiliguri(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                final id = g['id'] as String;
                final name = g['name'] as String? ?? 'গ্রুপ';
                final unseen = g['has_unseen'] == true;
                return Material(
                  color: unseen
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : null,
                  child: ListTile(
                    title: Text(
                      name,
                      style: GoogleFonts.hindSiliguri(
                        fontWeight: unseen ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: unseen
                        ? Text(
                            'নতুন মেসেজ আছে',
                            style: GoogleFonts.hindSiliguri(fontSize: 12),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unseen)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const Icon(Icons.chat),
                      ],
                    ),
                    onTap: () async {
                      await context.push(
                        '/student/community/$id?name=${Uri.encodeQueryComponent(name)}',
                      );
                      if (!mounted) return;
                      await _reload();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
