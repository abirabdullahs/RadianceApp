import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../widgets/admin_drawer.dart';
import '../../courses/providers/courses_provider.dart';
import '../repositories/exam_repository.dart';

/// Creates a new exam (draft) then navigates to detail.
class AdminExamEditorScreen extends ConsumerStatefulWidget {
  const AdminExamEditorScreen({super.key});

  @override
  ConsumerState<AdminExamEditorScreen> createState() =>
      _AdminExamEditorScreenState();
}

class _AdminExamEditorScreenState extends ConsumerState<AdminExamEditorScreen> {
  final _title = TextEditingController();
  final _duration = TextEditingController(text: '30');
  final _totalMarks = TextEditingController(text: '30');
  final _passMarks = TextEditingController(text: '15');
  final _neg = TextEditingController(text: '0');
  String? _courseId;
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _totalMarks.dispose();
    _passMarks.dispose();
    _neg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: const AppBarDrawerLeading(),
        automaticallyImplyLeading: false,
        leadingWidth: leadingWidthForDrawer(context),
        title: Text('নতুন পরীক্ষা', style: GoogleFonts.hindSiliguri()),
      ),
      body: coursesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text('প্রথমে একটি কোর্স যোগ করুন', style: GoogleFonts.hindSiliguri()),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _courseId ?? items.first.course.id,
                decoration: InputDecoration(
                  labelText: 'কোর্স',
                  labelStyle: GoogleFonts.hindSiliguri(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  for (final it in items)
                    DropdownMenuItem(
                      value: it.course.id,
                      child: Text(it.course.name, style: GoogleFonts.hindSiliguri()),
                    ),
                ],
                onChanged: (v) => setState(() => _courseId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'শিরোনাম',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: GoogleFonts.hindSiliguri(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'সময় (মিনিট)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _totalMarks,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'মোট নম্বর',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passMarks,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'পাস নম্বর',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _neg,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'নেগেটিভ মার্কিং (প্রতি ভুল)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await _save(context, items);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: context.themePrimary,
                  padding: const EdgeInsets.all(16),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('সংরক্ষণ', style: GoogleFonts.hindSiliguri(color: Colors.white)),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    List<CourseListItem> courseItems,
  ) async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('শিরোনাম লিখুন', style: GoogleFonts.hindSiliguri())),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final cid = _courseId ?? courseItems.first.course.id;
      final exam = await ExamRepository().createExam(
        courseId: cid,
        title: title,
        durationMinutes: int.tryParse(_duration.text) ?? 30,
        totalMarks: double.tryParse(_totalMarks.text),
        passMarks: double.tryParse(_passMarks.text),
        negativeMarking: double.tryParse(_neg.text) ?? 0,
        status: 'draft',
      );
      if (context.mounted) {
        context.go('/admin/exams/${exam.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
