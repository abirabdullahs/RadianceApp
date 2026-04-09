import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/models/course_model.dart';
import '../repositories/course_repository.dart';

part 'courses_provider.g.dart';

enum CourseListFilter {
  all,
  active,
  inactive,
}

/// One row for the admin course grid (course + enrollment count).
class CourseListItem {
  const CourseListItem({
    required this.course,
    required this.studentCount,
  });

  final CourseModel course;
  final int studentCount;
}

@Riverpod(keepAlive: true)
CourseRepository courseRepository(CourseRepositoryRef ref) {
  return CourseRepository();
}

/// Loads courses with enrollment counts; [CourseListFilter] via [setFilter].
@Riverpod(keepAlive: true)
class Courses extends _$Courses {
  CourseListFilter _filter = CourseListFilter.all;

  CourseListFilter get filter => _filter;

  void setFilter(CourseListFilter value) {
    if (_filter == value) return;
    _filter = value;
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  @override
  Future<List<CourseListItem>> build() async {
    final repo = ref.watch(courseRepositoryProvider);
    final courses = await repo.getCourses();
    final ids = courses.map((e) => e.id).toList();
    final counts = await repo.getEnrollmentCountsForCourses(ids);

    Iterable<CourseModel> filtered = courses;
    switch (_filter) {
      case CourseListFilter.all:
        break;
      case CourseListFilter.active:
        filtered = courses.where((c) => c.isActive);
        break;
      case CourseListFilter.inactive:
        filtered = courses.where((c) => !c.isActive);
        break;
    }

    return filtered
        .map(
          (c) => CourseListItem(
            course: c,
            studentCount: counts[c.id] ?? 0,
          ),
        )
        .toList();
  }
}
