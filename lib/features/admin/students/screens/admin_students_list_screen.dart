import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/course_model.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/repositories/course_repository.dart';
import '../repositories/student_repository.dart';

class _StudentListFilter {
  const _StudentListFilter({
    required this.query,
    required this.courseId,
  });

  final String query;
  final String? courseId;
}

final _studentListProvider =
    FutureProvider.autoDispose.family<List<UserModel>, _StudentListFilter>((ref, filter) async {
  return StudentRepository().getStudents(
    searchQuery: filter.query.isEmpty ? null : filter.query,
    courseId: filter.courseId,
  );
});

final _courseFilterOptionsProvider = FutureProvider.autoDispose<List<CourseModel>>((ref) async {
  final list = await CourseRepository().getCourses();
  return list.where((c) => c.isActive).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

/// Searchable list of students → profile route.
class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _selectedCourseId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = _StudentListFilter(
      query: _query,
      courseId: _selectedCourseId,
    );
    final async = ref.watch(_studentListProvider(filter));
    final courseAsync = ref.watch(_courseFilterOptionsProvider);

    return AdminResponsiveScaffold(
      title: Text('শিক্ষার্থী', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/students/add'),
        backgroundColor: context.themePrimary,
        icon: const Icon(Icons.person_add),
        label: Text('নতুন', style: GoogleFonts.hindSiliguri()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'নাম / ফোন / আইডি দিয়ে খুঁজুন',
                    hintStyle: GoogleFonts.hindSiliguri(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: GoogleFonts.hindSiliguri(),
                  onSubmitted: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 10),
                courseAsync.when(
                  data: (courses) {
                    return DropdownButtonFormField<String?>(
                      // ignore: deprecated_member_use
                      value: _selectedCourseId,
                      decoration: InputDecoration(
                        labelText: 'কোর্স অনুযায়ী ফিল্টার',
                        labelStyle: GoogleFonts.hindSiliguri(),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.filter_alt_outlined),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('সব কোর্স', style: GoogleFonts.hindSiliguri()),
                        ),
                        ...courses.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name, style: GoogleFonts.hindSiliguri()),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCourseId = v),
                    );
                  },
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('কোনো শিক্ষার্থী নেই', style: GoogleFonts.hindSiliguri()),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.themePrimary.withValues(alpha: 0.15),
                        child: Text(
                          u.fullNameBn.isNotEmpty ? u.fullNameBn[0] : '?',
                          style: TextStyle(color: context.themePrimary),
                        ),
                      ),
                      title: Text(u.fullNameBn, style: GoogleFonts.hindSiliguri()),
                      subtitle: Text(
                        u.studentId ?? u.phone,
                        style: GoogleFonts.nunito(fontSize: 12),
                      ),
                      onTap: () => context.push('/admin/students/${u.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }
}
