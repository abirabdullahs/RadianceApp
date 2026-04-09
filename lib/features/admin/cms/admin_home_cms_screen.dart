import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../widgets/admin_drawer.dart';
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

  /// Controllers must not be disposed until the dialog route is fully removed
  /// (otherwise TextField + disposed controller → red error screen).
  Future<void> _showAddBannerDialog() async {
    final title = TextEditingController();
    final url = TextEditingController();
    try {
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('বাতিল'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await HomeContentRepository().insertBanner(
                    title: title.text.trim().isEmpty ? 'ব্যানার' : title.text.trim(),
                    imageUrl: url.text.trim().isEmpty ? null : url.text.trim(),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _reload();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'সংরক্ষণ ব্যর্থ: $e',
                        style: GoogleFonts.hindSiliguri(color: Colors.white),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              child: Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri()),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          title.dispose();
          url.dispose();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('হোম কন্টেন্ট', style: GoogleFonts.hindSiliguri()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBannerDialog,
        backgroundColor: context.themePrimary,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'লোড ব্যর্থ: ${snap.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hindSiliguri(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            );
          }
          final rows = snap.data ?? [];
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
