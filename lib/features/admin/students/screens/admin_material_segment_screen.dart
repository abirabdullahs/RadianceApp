import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/course_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../courses/repositories/course_repository.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../repositories/student_repository.dart';

class AdminMaterialSegmentScreen extends ConsumerStatefulWidget {
  const AdminMaterialSegmentScreen({super.key});

  @override
  ConsumerState<AdminMaterialSegmentScreen> createState() =>
      _AdminMaterialSegmentScreenState();
}

class _AdminMaterialSegmentScreenState
    extends ConsumerState<AdminMaterialSegmentScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  List<CourseModel> _courses = const [];
  String? _selectedCourseId;
  List<UserModel> _students = const [];
  final Map<String, bool> _checked = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final list = await CourseRepository().getCourses();
      if (!mounted) return;
      setState(() {
        _courses = list.where((c) => c.isActive).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      });
    } catch (_) {}
  }

  Future<void> _loadStudentsForCourse(String? courseId) async {
    if (courseId == null || courseId.isEmpty) {
      setState(() {
        _students = const [];
        _checked.clear();
      });
      return;
    }
    try {
      final list = await StudentRepository().getStudents(courseId: courseId);
      if (!mounted) return;
      setState(() {
        _students = list;
        _checked
          ..clear()
          ..addEntries(list.map((u) => MapEntry<String, bool>(u.id, false)));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material name is required')),
      );
      return;
    }
    final courseId = _selectedCourseId;
    if (courseId == null || courseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a course')),
      );
      return;
    }
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No enrolled students found for this course')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = StudentRepository();
      final materialId = await repo.createMaterial(
        name: name,
        courseId: courseId,
        createdBy: supabaseClient.auth.currentUser?.id,
      );
      if (materialId.isEmpty) {
        throw StateError('failed_to_create_material');
      }
      await repo.saveMaterialAssignments(
        materialId: materialId,
        checksByStudentId: _checked,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Material saved for ${_students.length} students',
            style: GoogleFonts.nunito(),
          ),
        ),
      );
      setState(() {
        _nameCtrl.clear();
        _checked.updateAll((_, __) => false);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text('Material Segment', style: GoogleFonts.nunito()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Material Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedCourseId,
            decoration: const InputDecoration(
              labelText: 'Select Course',
              border: OutlineInputBorder(),
            ),
            items: _courses
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.name, style: GoogleFonts.hindSiliguri()),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (v) async {
                    setState(() => _selectedCourseId = v);
                    await _loadStudentsForCourse(v);
                  },
          ),
          const SizedBox(height: 16),
          Text(
            'All Enrolled Students of Selected Course',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_students.isEmpty)
            Text(
              'No students loaded',
              style: GoogleFonts.nunito(color: Colors.black54),
            )
          else
            ..._students.map(
              (u) => CheckboxListTile(
                value: _checked[u.id] ?? false,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _checked[u.id] = v ?? false),
                title: Text(u.fullNameBn, style: GoogleFonts.hindSiliguri()),
                subtitle: Text(
                  u.studentId ?? u.phone,
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Saving...' : 'Save Material Assignments',
              style: GoogleFonts.nunito(),
            ),
            style: FilledButton.styleFrom(backgroundColor: context.themePrimary),
          ),
        ],
      ),
    );
  }
}
