import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/models/chapter_model.dart';
import '../../../shared/models/course_model.dart';
import '../../../shared/models/subject_model.dart';
import '../../admin/courses/repositories/course_repository.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Future<_CourseBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CourseBundle> _load() async {
    final repo = CourseRepository();
    final course = await repo.getCourseById(widget.courseId);
    final subjects = await repo.getSubjects(widget.courseId);
    final chaptersBySubject = <String, List<ChapterModel>>{};
    for (final s in subjects) {
      chaptersBySubject[s.id] = await repo.getChapters(s.id);
    }
    return _CourseBundle(
      course: course,
      subjects: subjects,
      chaptersBySubject: chaptersBySubject,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CourseBundle>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final b = snap.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(b.course.name, style: GoogleFonts.hindSiliguri()),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (b.course.description != null && b.course.description!.isNotEmpty)
                Text(b.course.description!, style: GoogleFonts.hindSiliguri()),
              const SizedBox(height: 16),
              Text(
                'বিষয়সমূহ',
                style: GoogleFonts.hindSiliguri(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              ...b.subjects.map(
                (s) => ExpansionTile(
                  title: Text(s.name, style: GoogleFonts.hindSiliguri()),
                  children: [
                    for (final ch in b.chaptersBySubject[s.id] ?? <ChapterModel>[])
                      ListTile(
                        title: Text(ch.name, style: GoogleFonts.hindSiliguri()),
                        trailing: const Icon(Icons.notes),
                        onTap: () =>
                            context.push('/student/notes/${ch.id}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourseBundle {
  const _CourseBundle({
    required this.course,
    required this.subjects,
    required this.chaptersBySubject,
  });

  final CourseModel course;
  final List<SubjectModel> subjects;
  final Map<String, List<ChapterModel>> chaptersBySubject;
}
