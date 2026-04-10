import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../repositories/course_repository.dart';
import '../widgets/admin_course_syllabus_tab.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/course_model.dart';

/// Admin: course summary + syllabus (subjects → chapters → lectures & suggestions).
class AdminCourseDetailScreen extends StatefulWidget {
  const AdminCourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<AdminCourseDetailScreen> createState() => _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen> {
  late Future<CourseModel> _future;

  @override
  void initState() {
    super.initState();
    _future = CourseRepository().getCourseById(widget.courseId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<CourseModel>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return AdminResponsiveScaffold(
            title: Text('কোর্স', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return AdminResponsiveScaffold(
            title: Text('কোর্স', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'লোড করা যায়নি:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hindSiliguri(color: scheme.error),
                ),
              ),
            ),
          );
        }
        final c = snap.data!;
        return DefaultTabController(
          length: 2,
          child: AdminResponsiveScaffold(
            title: Text(
              c.name,
              style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            bottom: TabBar(
              tabs: [
                Tab(child: Text('তথ্য', style: GoogleFonts.hindSiliguri())),
                Tab(child: Text('সিলেবাস', style: GoogleFonts.hindSiliguri())),
              ],
            ),
            body: TabBarView(
              children: [
                _CourseOverviewBody(course: c),
                AdminCourseSyllabusTab(courseId: c.id),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CourseOverviewBody extends StatelessWidget {
  const _CourseOverviewBody({required this.course});

  final CourseModel course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = course;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: c.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, _, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Icon(Icons.menu_book_outlined, size: 48, color: scheme.onSurfaceVariant),
          ),
        const SizedBox(height: 20),
        Text(
          c.name,
          style: GoogleFonts.hindSiliguri(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              label: Text(
                c.isActive ? 'সক্রিয়' : 'নিষ্ক্রিয়',
                style: GoogleFonts.hindSiliguri(fontSize: 13),
              ),
              backgroundColor: c.isActive
                  ? context.themePrimary.withValues(alpha: 0.15)
                  : scheme.surfaceContainerHighest,
            ),
            Chip(
              label: Text(
                'মাসিক ৳${c.monthlyFee.toStringAsFixed(0)}',
                style: GoogleFonts.hindSiliguri(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'বিবরণ',
          style: GoogleFonts.hindSiliguri(
            fontWeight: FontWeight.w600,
            color: context.themePrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (c.description != null && c.description!.trim().isNotEmpty)
              ? c.description!.trim()
              : 'কোনো বিবরণ যোগ করা হয়নি।',
          style: GoogleFonts.hindSiliguri(
            fontSize: 15,
            height: 1.45,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.push(
            '/admin/courses/${c.id}/notice?name=${Uri.encodeComponent(c.name)}',
          ),
          icon: const Icon(Icons.campaign_outlined),
          label: Text('ছাত্রদের নোটিশ পাঠান', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 24),
        Text(
          'কোর্স আইডি',
          style: GoogleFonts.hindSiliguri(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          c.id,
          style: GoogleFonts.nunito(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
