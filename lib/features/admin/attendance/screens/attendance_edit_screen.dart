import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/supabase_client.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/attendance_providers.dart';
import '../repositories/attendance_repository.dart';

class AttendanceEditScreen extends ConsumerStatefulWidget {
  const AttendanceEditScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<AttendanceEditScreen> createState() => _AttendanceEditScreenState();
}

class _AttendanceEditScreenState extends ConsumerState<AttendanceEditScreen> {
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _saving = false;
  int _reloadSeed = 0;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(attendanceRepositoryProvider);
    return AdminResponsiveScaffold(
      title: Text('উপস্থিতি সম্পাদনা', style: GoogleFonts.hindSiliguri()),
      body: FutureBuilder<_EditData>(
        future: _load(repo, widget.sessionId, _reloadSeed),
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            return const Center(child: CircularProgressIndicator());
          }
          return _EditorBody(
            data: snap.data!,
            saving: _saving,
            reasonCtrl: _reasonCtrl,
            onSave: (statuses) => _save(statuses),
          );
        },
      ),
    );
  }

  Future<_EditData> _load(
    AttendanceRepository repo,
    String sessionId,
    int _,
  ) async {
    final session = await repo.getSessionById(sessionId);
    final records = await repo.getEditableRecords(sessionId);
    if (session == null) {
      throw Exception('সেশন পাওয়া যায়নি');
    }
    return _EditData(session: session, records: records);
  }

  Future<void> _save(Map<String, String> statuses) async {
    final uid = supabaseClient.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final changedCount = await ref.read(attendanceRepositoryProvider).updateAttendanceRecordsWithLog(
            sessionId: widget.sessionId,
            nextStatusByStudentId: statuses,
            changedBy: uid,
            reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changedCount == 0
                ? 'কোনো পরিবর্তন পাওয়া যায়নি'
                : 'পরিবর্তন সংরক্ষণ হয়েছে ($changedCount টি)',
            style: GoogleFonts.hindSiliguri(),
          ),
        ),
      );
      setState(() => _reloadSeed++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('সংরক্ষণ ব্যর্থ: $e', style: GoogleFonts.hindSiliguri())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EditData {
  const _EditData({required this.session, required this.records});
  final Map<String, dynamic> session;
  final List<AttendanceEditableRecord> records;
}

class _EditorBody extends StatefulWidget {
  const _EditorBody({
    required this.data,
    required this.saving,
    required this.reasonCtrl,
    required this.onSave,
  });

  final _EditData data;
  final bool saving;
  final TextEditingController reasonCtrl;
  final Future<void> Function(Map<String, String> statuses) onSave;

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  late Map<String, String> _statusByStudentId;

  @override
  void initState() {
    super.initState();
    _statusByStudentId = {
      for (final r in widget.data.records) r.studentId: r.status,
    };
  }

  @override
  void didUpdateWidget(covariant _EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.records != widget.data.records) {
      _statusByStudentId = {
        for (final r in widget.data.records) r.studentId: r.status,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(widget.data.session['date'] as String? ?? '');
    final total = _statusByStudentId.length;
    final present = _statusByStudentId.values.where((s) => s == 'present' || s == 'late').length;
    final absent = _statusByStudentId.values.where((s) => s == 'absent').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'তারিখ: ${_dateLabel(date)}',
          style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'উপস্থিত: $present  |  অনুপস্থিত: $absent  |  মোট: $total',
          style: GoogleFonts.hindSiliguri(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.saving ? null : () => widget.onSave(_statusByStudentId),
            icon: const Icon(Icons.save_outlined),
            label: Text(
              widget.saving ? 'সংরক্ষণ হচ্ছে...' : 'Save Changes',
              style: GoogleFonts.hindSiliguri(color: Colors.white),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: context.themePrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in widget.data.records.asMap().entries) ...[
          (() {
            final i = entry.key;
            final r = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text(
                        '${i + 1}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.studentNameBn, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                          Text(r.studentCode ?? '—', style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _statusByStudentId[r.studentId] ?? 'absent',
                      items: const [
                        DropdownMenuItem(value: 'present', child: Text('উপস্থিত')),
                        DropdownMenuItem(value: 'absent', child: Text('অনুপস্থিত')),
                        DropdownMenuItem(value: 'late', child: Text('দেরি')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _statusByStudentId[r.studentId] = v);
                      },
                    ),
                  ],
                ),
              ),
            );
          })(),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: widget.reasonCtrl,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'পরিবর্তনের কারণ (optional)',
            labelStyle: GoogleFonts.hindSiliguri(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.saving ? null : () => widget.onSave(_statusByStudentId),
            style: FilledButton.styleFrom(
              backgroundColor: context.themePrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              widget.saving ? 'সংরক্ষণ হচ্ছে...' : '💾 পরিবর্তন সংরক্ষণ করুন',
              style: GoogleFonts.hindSiliguri(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
