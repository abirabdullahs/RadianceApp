import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    _future = CommunityRepository().listGroupsForCurrentStudent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('গ্রুপ চ্যাট', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data!;
          if (groups.isEmpty) {
            return Center(
              child: Text('কোনো গ্রুপ নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              final id = g['id'] as String;
              final name = g['name'] as String? ?? 'গ্রুপ';
              return ListTile(
                title: Text(name, style: GoogleFonts.hindSiliguri()),
                trailing: const Icon(Icons.chat),
                onTap: () => context.push(
                  '/student/community/$id?name=${Uri.encodeQueryComponent(name)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
