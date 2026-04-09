import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../courses/providers/courses_provider.dart';

/// Pick course + date, then open [AttendanceTakingScreen].
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _courseId;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('উপস্থিতি', style: GoogleFonts.hindSiliguri()),
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
              Text(
                'কোর্স',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _courseId ?? items.first.course.id,
                decoration: InputDecoration(
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
              const SizedBox(height: 24),
              Text(
                'তারিখ',
                style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                title: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: GoogleFonts.nunito(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(DateTime.now().year - 1),
                    lastDate: DateTime(DateTime.now().year + 1),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  final cid = _courseId ?? items.first.course.id;
                  final path =
                      '/admin/attendance/$cid/${_sqlDate(_date)}';
                  context.push(path);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'উপস্থিতি নিতে যান',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

String _sqlDate(DateTime d) {
  final u = DateTime(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
