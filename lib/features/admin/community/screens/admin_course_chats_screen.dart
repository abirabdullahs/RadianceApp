import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../student/community/repositories/community_repository.dart';
import '../../widgets/admin_responsive_scaffold.dart';

/// Admin: list of per-course messenger groups; tap opens realtime chat.
class AdminCourseChatsScreen extends StatefulWidget {
  const AdminCourseChatsScreen({super.key});

  @override
  State<AdminCourseChatsScreen> createState() => _AdminCourseChatsScreenState();
}

class _AdminCourseChatsScreenState extends State<AdminCourseChatsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = CommunityRepository().listCourseGroupsForAdmin();
  }

  String _titleForRow(Map<String, dynamic> row) {
    final c = row['courses'];
    if (c is Map && (c['name'] as String?)?.trim().isNotEmpty == true) {
      return (c['name'] as String).trim();
    }
    return row['name'] as String? ?? 'কোর্স';
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text(
        'কোর্স চ্যাট',
        style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'রিফ্রেশ',
          onPressed: () {
            setState(() {
              _future = CommunityRepository().listCourseGroupsForAdmin();
            });
          },
        ),
      ],
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'লোড করা যায়নি: ${snap.error}',
                  style: GoogleFonts.hindSiliguri(),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Text(
                'কোনো কোর্স নেই। কোর্স তৈরি হলে গ্রুপ স্বয়ংক্রিয়ভাবে যুক্ত হবে।',
                style: GoogleFonts.hindSiliguri(),
                textAlign: TextAlign.center,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = CommunityRepository().listCourseGroupsForAdmin();
              });
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final row = list[i];
                final id = row['id'] as String;
                final title = _titleForRow(row);
                final groupName = row['name'] as String? ?? title;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.themePrimary.withValues(alpha: 0.15),
                    child: Icon(Icons.forum_outlined, color: context.themePrimary),
                  ),
                  title: Text(title, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'কোর্স গ্রুপ চ্যাট',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '/admin/course-chats/$id?name=${Uri.encodeQueryComponent(groupName)}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
