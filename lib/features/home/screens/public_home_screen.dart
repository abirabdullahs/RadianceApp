import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/models/course_model.dart';
import '../../admin/courses/repositories/course_repository.dart';
import '../repositories/home_content_repository.dart';

/// Marketing home (no auth): banners + active courses + login CTA.
class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key});

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  late Future<_PublicBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PublicBundle> _load() async {
    final content = await HomeContentRepository().listActivePublic();
    final courses = await CourseRepository().getCourses();
    final active = courses.where((c) => c.isActive).toList();
    return _PublicBundle(content: content, courses: active);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Radiance', style: GoogleFonts.hindSiliguri()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/login'),
                  child: Text('লগইন', style: GoogleFonts.hindSiliguri()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/login'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: Text(
                    'অ্যাকাউন্ট',
                    style: GoogleFonts.hindSiliguri(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<_PublicBundle>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _load();
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'নোটিশ ও ব্যানার',
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (b.content.isEmpty)
                  Text('শীঘ্রই আপডেট', style: GoogleFonts.hindSiliguri())
                else
                  ...b.content.map(
                    (row) {
                      final type = row['type'] as String? ?? '';
                      final title = row['title'] as String? ?? '';
                      final img = row['image_url'] as String?;
                      if (type == 'banner' && img != null && img.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: img,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }
                      return ListTile(
                        title: Text(title, style: GoogleFonts.hindSiliguri()),
                        subtitle: Text(type, style: GoogleFonts.nunito(fontSize: 12)),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Text(
                  'কোর্সসমূহ',
                  style: GoogleFonts.hindSiliguri(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (b.courses.isEmpty)
                  Text('কোনো কোর্স নেই', style: GoogleFonts.hindSiliguri())
                else
                  ...b.courses.map(
                    (c) => Card(
                      child: ListTile(
                        leading: c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: c.thumbnailUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.school, color: AppTheme.primary),
                        title: Text(c.name, style: GoogleFonts.hindSiliguri()),
                        subtitle: Text(
                          '৳${c.monthlyFee.toStringAsFixed(0)}/মাস',
                          style: GoogleFonts.nunito(),
                        ),
                        onTap: () => context.push('/login'),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PublicBundle {
  const _PublicBundle({required this.content, required this.courses});

  final List<Map<String, dynamic>> content;
  final List<CourseModel> courses;
}
