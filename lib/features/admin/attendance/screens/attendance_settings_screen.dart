import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../shared/models/attendance_settings_model.dart';
import '../../widgets/admin_responsive_scaffold.dart';
import '../providers/attendance_providers.dart';

class AttendanceSettingsScreen extends ConsumerStatefulWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  ConsumerState<AttendanceSettingsScreen> createState() => _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState extends ConsumerState<AttendanceSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  AttendanceSettingsModel _settings = const AttendanceSettingsModel();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ref.read(attendanceRepositoryProvider).getAttendanceSettings();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ref.read(attendanceRepositoryProvider).saveAttendanceSettings(_settings);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('উপস্থিতি সেটিংস সংরক্ষণ হয়েছে', style: GoogleFonts.hindSiliguri())),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveScaffold(
      title: Text('উপস্থিতি সেটিংস', style: GoogleFonts.hindSiliguri()),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('সতর্কতার সীমা', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${_settings.warningThresholdPct}% এর নিচে হলে alert', style: GoogleFonts.hindSiliguri()),
                Slider(
                  value: _settings.warningThresholdPct.toDouble(),
                  min: 50,
                  max: 95,
                  divisions: 45,
                  label: '${_settings.warningThresholdPct}%',
                  onChanged: (v) => setState(() => _settings = AttendanceSettingsModel(
                    warningThresholdPct: v.round(),
                    autoSmsEnabled: _settings.autoSmsEnabled,
                    sortOrder: _settings.sortOrder,
                    autoAdvanceDelayMs: _settings.autoAdvanceDelayMs,
                    defaultStatus: _settings.defaultStatus,
                  )),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: Text('Auto SMS (<threshold হলে)', style: GoogleFonts.hindSiliguri()),
                  value: _settings.autoSmsEnabled,
                  onChanged: (v) => setState(() => _settings = AttendanceSettingsModel(
                    warningThresholdPct: _settings.warningThresholdPct,
                    autoSmsEnabled: v,
                    sortOrder: _settings.sortOrder,
                    autoAdvanceDelayMs: _settings.autoAdvanceDelayMs,
                    defaultStatus: _settings.defaultStatus,
                  )),
                ),
                const SizedBox(height: 10),
                Text('Student সাজানোর ক্রম', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                RadioListTile<String>(
                  value: 'roll',
                  groupValue: _settings.sortOrder,
                  title: Text('Roll Number অনুযায়ী', style: GoogleFonts.hindSiliguri()),
                  onChanged: _setSortOrder,
                ),
                RadioListTile<String>(
                  value: 'name_en',
                  groupValue: _settings.sortOrder,
                  title: Text('নাম অনুযায়ী (A-Z)', style: GoogleFonts.hindSiliguri()),
                  onChanged: _setSortOrder,
                ),
                RadioListTile<String>(
                  value: 'name_bn',
                  groupValue: _settings.sortOrder,
                  title: Text('নাম অনুযায়ী (বাংলা)', style: GoogleFonts.hindSiliguri()),
                  onChanged: _setSortOrder,
                ),
                RadioListTile<String>(
                  value: 'join_date',
                  groupValue: _settings.sortOrder,
                  title: Text('যোগদানের তারিখ অনুযায়ী', style: GoogleFonts.hindSiliguri()),
                  onChanged: _setSortOrder,
                ),
                const SizedBox(height: 10),
                Text('Auto-advance delay', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${(_settings.autoAdvanceDelayMs / 1000).toStringAsFixed(1)} সেকেন্ড', style: GoogleFonts.nunito()),
                Slider(
                  value: _settings.autoAdvanceDelayMs.toDouble(),
                  min: 0,
                  max: 1000,
                  divisions: 10,
                  onChanged: (v) => setState(() => _settings = AttendanceSettingsModel(
                    warningThresholdPct: _settings.warningThresholdPct,
                    autoSmsEnabled: _settings.autoSmsEnabled,
                    sortOrder: _settings.sortOrder,
                    autoAdvanceDelayMs: v.round(),
                    defaultStatus: _settings.defaultStatus,
                  )),
                ),
                const SizedBox(height: 10),
                Text('Default Status', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700)),
                RadioListTile<String>(
                  value: 'absent',
                  groupValue: _settings.defaultStatus,
                  title: Text('সব Absent থেকে শুরু', style: GoogleFonts.hindSiliguri()),
                  onChanged: _setDefaultStatus,
                ),
                RadioListTile<String>(
                  value: 'present',
                  groupValue: _settings.defaultStatus,
                  title: Text('সব Present থেকে শুরু', style: GoogleFonts.hindSiliguri()),
                  onChanged: _setDefaultStatus,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: context.themePrimary),
                  child: Text(
                    _saving ? 'সংরক্ষণ হচ্ছে...' : 'সেটিংস সংরক্ষণ করুন',
                    style: GoogleFonts.hindSiliguri(color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  void _setSortOrder(String? value) {
    if (value == null) return;
    setState(() => _settings = AttendanceSettingsModel(
      warningThresholdPct: _settings.warningThresholdPct,
      autoSmsEnabled: _settings.autoSmsEnabled,
      sortOrder: value,
      autoAdvanceDelayMs: _settings.autoAdvanceDelayMs,
      defaultStatus: _settings.defaultStatus,
    ));
  }

  void _setDefaultStatus(String? value) {
    if (value == null) return;
    setState(() => _settings = AttendanceSettingsModel(
      warningThresholdPct: _settings.warningThresholdPct,
      autoSmsEnabled: _settings.autoSmsEnabled,
      sortOrder: _settings.sortOrder,
      autoAdvanceDelayMs: _settings.autoAdvanceDelayMs,
      defaultStatus: value,
    ));
  }
}
