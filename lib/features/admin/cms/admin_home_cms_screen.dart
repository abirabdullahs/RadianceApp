import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../home/repositories/home_content_repository.dart';

/// Manage [home_content] rows (banners, notices).
class AdminHomeCmsScreen extends StatefulWidget {
  const AdminHomeCmsScreen({super.key});

  @override
  State<AdminHomeCmsScreen> createState() => _AdminHomeCmsScreenState();
}

class _AdminHomeCmsScreenState extends State<AdminHomeCmsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = HomeContentRepository().listAllForAdmin();
  }

  Future<void> _reload() async {
    setState(() {
      _future = HomeContentRepository().listAllForAdmin();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('হোম কন্টেন্ট', style: GoogleFonts.hindSiliguri()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final title = TextEditingController();
          final url = TextEditingController();
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('ব্যানার', style: GoogleFonts.hindSiliguri()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'শিরোনাম'),
                  ),
                  TextField(
                    controller: url,
                    decoration: const InputDecoration(labelText: 'ছবির URL'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('বাতিল'),
                ),
                FilledButton(
                  onPressed: () async {
                    await HomeContentRepository().insertBanner(
                      title: title.text.trim().isEmpty ? 'ব্যানার' : title.text.trim(),
                      imageUrl: url.text.trim().isEmpty ? null : url.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _reload();
                  },
                  child: Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri()),
                ),
              ],
            ),
          ).whenComplete(() {
            title.dispose();
            url.dispose();
          });
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return Center(
              child: Text('কোনো আইটেম নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final id = r['id'] as String;
                final title = r['title'] as String? ?? '';
                final type = r['type'] as String? ?? '';
                final active = r['is_active'] as bool? ?? false;
                return SwitchListTile(
                  title: Text(title, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(type, style: GoogleFonts.nunito(fontSize: 12)),
                  value: active,
                  onChanged: (v) async {
                    await HomeContentRepository().setActive(id, v);
                    await _reload();
                  },
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await HomeContentRepository().deleteRow(id);
                      await _reload();
                    },
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
