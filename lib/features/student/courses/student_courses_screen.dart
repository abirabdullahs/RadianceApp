import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/models/enrollment_model.dart';
import '../../admin/courses/repositories/course_repository.dart';
import '../../admin/students/repositories/student_repository.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  late Future<List<_CourseTile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_CourseTile>> _load() async {
    final uid = supabaseClient.auth.currentUser!.id;
    final en = await StudentRepository().getMyEnrollments();
    final cRepo = CourseRepository();
    final out = <_CourseTile>[];
    for (final e in en) {
      try {
        final c = await cRepo.getCourseById(e.courseId);
        out.add(_CourseTile(course: c, enrollment: e));
      } catch (_) {}
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('আমার কোর্স', style: GoogleFonts.hindSiliguri()),
      ),
      body: FutureBuilder<List<_CourseTile>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Text('কোনো কোর্স নেই', style: GoogleFonts.hindSiliguri()),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              final c = t.course;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      : const Icon(Icons.school, size: 40, color: AppTheme.primary),
                  title: Text(c.name, style: GoogleFonts.hindSiliguri()),
                  subtitle: Text(
                    '৳${c.monthlyFee.toStringAsFixed(0)}/মাস',
                    style: GoogleFonts.nunito(),
                  ),
                  onTap: () => context.push('/student/courses/${c.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CourseTile {
  const _CourseTile({required this.course, required this.enrollment});

  final CourseModel course;
  final EnrollmentModel enrollment;
}
