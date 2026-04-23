import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/attendance_settings_model.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/user_model.dart';

class AttendanceCourseSessionSummary {
  const AttendanceCourseSessionSummary({
    required this.courseId,
    required this.sessionId,
    required this.isCompleted,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
  });

  final String courseId;
  final String sessionId;
  final bool isCompleted;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
}

class AttendanceSessionListItem {
  const AttendanceSessionListItem({
    required this.sessionId,
    required this.sessionDate,
    required this.isCompleted,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
  });

  final String sessionId;
  final DateTime sessionDate;
  final bool isCompleted;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
}

class AttendanceEditableRecord {
  const AttendanceEditableRecord({
    required this.recordId,
    required this.studentId,
    required this.studentNameBn,
    required this.studentCode,
    required this.status,
  });

  final String recordId;
  final String studentId;
  final String studentNameBn;
  final String? studentCode;
  final String status;
}

class AttendanceDailyReport {
  const AttendanceDailyReport({
    required this.sessionId,
    required this.courseId,
    required this.date,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.presentStudents,
    required this.absentStudents,
  });

  final String sessionId;
  final String courseId;
  final DateTime date;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final List<AttendanceEditableRecord> presentStudents;
  final List<AttendanceEditableRecord> absentStudents;
}

class AttendanceMonthlyStudentSummary {
  const AttendanceMonthlyStudentSummary({
    required this.studentId,
    required this.studentNameBn,
    required this.studentCode,
    required this.totalClasses,
    required this.present,
    required this.absent,
    required this.percentage,
  });

  final String studentId;
  final String studentNameBn;
  final String? studentCode;
  final int totalClasses;
  final int present;
  final int absent;
  final double percentage;
}

class AttendanceWarningRecipient {
  const AttendanceWarningRecipient({
    required this.studentId,
    required this.studentNameBn,
    required this.studentCode,
    required this.phone,
    required this.guardianPhone,
    required this.percentage,
  });

  final String studentId;
  final String studentNameBn;
  final String? studentCode;
  final String? phone;
  final String? guardianPhone;
  final double percentage;
}

class AttendanceWeeklyRecipient {
  const AttendanceWeeklyRecipient({
    required this.studentId,
    required this.studentNameBn,
    required this.studentCode,
    required this.percentage,
  });

  final String studentId;
  final String studentNameBn;
  final String? studentCode;
  final double percentage;
}

/// Attendance sessions and per-student records (Supabase).
class AttendanceRepository {
  AttendanceRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Returns existing row or inserts a new session for [courseId] + calendar [date].
  Future<String> getOrCreateSession({
    required String courseId,
    required DateTime date,
    String? createdBy,
  }) async {
    final dateStr = _sqlDate(date);
    final existing = await _client
        .from(kTableAttendanceSessions)
        .select('id')
        .eq('course_id', courseId)
        .eq('date', dateStr)
        .maybeSingle();

    if (existing != null) {
      return Map<String, dynamic>.from(existing)['id'] as String;
    }

    final row = await _client.from(kTableAttendanceSessions).insert(<String, dynamic>{
      'course_id': courseId,
      'date': dateStr,
      'created_by': createdBy,
    }).select('id').single();

    return Map<String, dynamic>.from(row)['id'] as String;
  }

  /// Active enrollments only, ordered by Bengali name.
  Future<List<UserModel>> getActiveStudentsForCourse(String courseId) async {
    final en = await _client
        .from(kTableEnrollments)
        .select('student_id')
        .eq('course_id', courseId)
        .eq('status', EnrollmentStatus.active.toJson());

    final ids = (en as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['student_id'] as String)
        .toList();

    if (ids.isEmpty) return [];

    final rows = await _client
        .from(kTableUsers)
        .select()
        .inFilter('id', ids)
        .eq('role', UserRole.student.toJson())
        .order('full_name_bn', ascending: true);

    return (rows as List<dynamic>)
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Returns session id for [courseId] and [date] if exists.
  Future<String?> getSessionIdForCourseAndDate({
    required String courseId,
    required DateTime date,
  }) async {
    final dateStr = _sqlDate(date);
    final row = await _client
        .from(kTableAttendanceSessions)
        .select('id')
        .eq('course_id', courseId)
        .eq('date', dateStr)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row)['id'] as String?;
  }

  /// For today's home cards: keyed by `course_id`.
  Future<Map<String, AttendanceCourseSessionSummary>> getCourseSessionsForDate({
    required List<String> courseIds,
    required DateTime date,
  }) async {
    if (courseIds.isEmpty) return <String, AttendanceCourseSessionSummary>{};
    final dateStr = _sqlDate(date);
    final rows = await _client
        .from(kTableAttendanceSessions)
        .select(
          'id, course_id, is_completed, total_students, present_count, absent_count',
        )
        .inFilter('course_id', courseIds)
        .eq('date', dateStr);

    final out = <String, AttendanceCourseSessionSummary>{};
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final courseId = m['course_id'] as String?;
      if (courseId == null) continue;
      out[courseId] = AttendanceCourseSessionSummary(
        courseId: courseId,
        sessionId: (m['id'] as String?) ?? '',
        isCompleted: m['is_completed'] as bool? ?? false,
        totalStudents: (m['total_students'] as num?)?.toInt() ?? 0,
        presentCount: (m['present_count'] as num?)?.toInt() ?? 0,
        absentCount: (m['absent_count'] as num?)?.toInt() ?? 0,
      );
    }
    return out;
  }

  Future<List<AttendanceSessionListItem>> getRecentSessionsForCourse(
    String courseId, {
    int limit = 12,
  }) async {
    final rows = await _client
        .from(kTableAttendanceSessions)
        .select('id, date, is_completed, total_students, present_count, absent_count')
        .eq('course_id', courseId)
        .order('date', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return AttendanceSessionListItem(
        sessionId: m['id'] as String? ?? '',
        sessionDate: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        isCompleted: m['is_completed'] as bool? ?? false,
        totalStudents: (m['total_students'] as num?)?.toInt() ?? 0,
        presentCount: (m['present_count'] as num?)?.toInt() ?? 0,
        absentCount: (m['absent_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<Map<String, dynamic>?> getSessionById(String sessionId) async {
    final row = await _client
        .from(kTableAttendanceSessions)
        .select('id, course_id, date, is_completed, total_students, present_count, absent_count')
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<AttendanceEditableRecord>> getEditableRecords(String sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) return const <AttendanceEditableRecord>[];
    final courseId = session['course_id'] as String? ?? '';
    if (courseId.isEmpty) return const <AttendanceEditableRecord>[];

    final students = await getActiveStudentsForCourse(courseId);
    final rows = await _client
        .from(kTableAttendanceRecords)
        .select('id, student_id, status')
        .eq('session_id', sessionId);
    final byStudent = <String, Map<String, dynamic>>{};
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String? ?? '';
      if (sid.isEmpty) continue;
      byStudent[sid] = m;
    }

    final out = <AttendanceEditableRecord>[];
    for (final s in students) {
      final existing = byStudent[s.id];
      out.add(
        AttendanceEditableRecord(
          recordId: existing?['id'] as String? ?? '',
          studentId: s.id,
          studentNameBn: s.fullNameBn,
          studentCode: s.studentId,
          status: existing?['status'] as String? ?? 'absent',
        ),
      );
    }
    out.sort((a, b) => a.studentNameBn.compareTo(b.studentNameBn));
    return out;
  }

  Future<int> updateAttendanceRecordsWithLog({
    required String sessionId,
    required Map<String, String> nextStatusByStudentId,
    required String changedBy,
    String? reason,
  }) async {
    final rows = await _client
        .from(kTableAttendanceRecords)
        .select('id, student_id, status')
        .eq('session_id', sessionId);
    final byStudent = <String, Map<String, dynamic>>{};
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sid = m['student_id'] as String? ?? '';
      if (sid.isEmpty) continue;
      byStudent[sid] = m;
    }

    var changedCount = 0;
    for (final entry in nextStatusByStudentId.entries) {
      final studentId = entry.key;
      final nextStatus = entry.value;
      final current = byStudent[studentId];
      final oldStatus = current?['status'] as String? ?? 'absent';
      if (nextStatus == oldStatus && current != null) continue;

      final saved = await _client
          .from(kTableAttendanceRecords)
          .upsert(
            <String, dynamic>{
              'session_id': sessionId,
              'student_id': studentId,
              'status': nextStatus,
            },
            onConflict: 'session_id,student_id',
          )
          .select('id, status')
          .single();
      final recordId = saved['id'] as String? ?? '';
      if (recordId.isEmpty || oldStatus == nextStatus) continue;
      await _client.from(kTableAttendanceEditLog).insert({
        'record_id': recordId,
        'old_status': oldStatus,
        'new_status': nextStatus,
        'changed_by': changedBy,
        'reason': reason,
      });
      changedCount += 1;
    }
    return changedCount;
  }

  Future<AttendanceDailyReport> getDailyReportBySession(String sessionId) async {
    final session = await getSessionById(sessionId);
    if (session == null) {
      throw Exception('সেশন পাওয়া যায়নি');
    }
    final records = await getEditableRecords(sessionId);
    final presentStudents = records.where((r) => r.status == 'present' || r.status == 'late').toList();
    final absentStudents = records.where((r) => r.status == 'absent').toList();
    final date = DateTime.tryParse(session['date'] as String? ?? '') ?? DateTime.now();
    return AttendanceDailyReport(
      sessionId: sessionId,
      courseId: session['course_id'] as String? ?? '',
      date: date,
      totalStudents: records.length,
      presentCount: presentStudents.length,
      absentCount: absentStudents.length,
      presentStudents: presentStudents,
      absentStudents: absentStudents,
    );
  }

  Future<List<AttendanceMonthlyStudentSummary>> getCourseMonthlySummary({
    required String courseId,
    required DateTime month,
  }) async {
    final start = DateTime.utc(month.year, month.month, 1);
    final end = DateTime.utc(month.year, month.month + 1, 1).subtract(const Duration(days: 1));
    final sessions = await _client
        .from(kTableAttendanceSessions)
        .select('id')
        .eq('course_id', courseId)
        .gte('date', _sqlDate(start))
        .lte('date', _sqlDate(end));
    final sessionIds = (sessions as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['id'] as String)
        .toList();
    if (sessionIds.isEmpty) return const <AttendanceMonthlyStudentSummary>[];

    final records = await _client
        .from(kTableAttendanceRecords)
        .select('student_id, status, users!inner(full_name_bn, student_id)')
        .inFilter('session_id', sessionIds);

    final map = <String, _Agg>{};
    for (final raw in records as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final studentId = m['student_id'] as String? ?? '';
      if (studentId.isEmpty) continue;
      final user = _relatedUserMap(m['users']);
      final status = m['status'] as String? ?? 'absent';
      final agg = map.putIfAbsent(
        studentId,
        () => _Agg(
          studentId: studentId,
          studentNameBn: user['full_name_bn'] as String? ?? '—',
          studentCode: user['student_id'] as String?,
        ),
      );
      agg.total++;
      if (status == 'present' || status == 'late') {
        agg.present++;
      } else {
        agg.absent++;
      }
    }

    final out = map.values
        .map((a) => AttendanceMonthlyStudentSummary(
              studentId: a.studentId,
              studentNameBn: a.studentNameBn,
              studentCode: a.studentCode,
              totalClasses: a.total,
              present: a.present,
              absent: a.absent,
              percentage: a.total == 0 ? 0 : (a.present * 100.0) / a.total,
            ))
        .toList()
      ..sort((a, b) => a.percentage.compareTo(b.percentage));
    return out;
  }

  Future<List<Map<String, dynamic>>> getAttendanceTrend30Days(String courseId) async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 29));
    final sessions = await _client
        .from(kTableAttendanceSessions)
        .select('id, date')
        .eq('course_id', courseId)
        .gte('date', _sqlDate(start))
        .lte('date', _sqlDate(end))
        .order('date', ascending: true);
    final sRows = sessions as List<dynamic>;
    if (sRows.isEmpty) return const <Map<String, dynamic>>[];
    final out = <Map<String, dynamic>>[];
    for (final raw in sRows) {
      final s = Map<String, dynamic>.from(raw as Map);
      final sid = s['id'] as String? ?? '';
      if (sid.isEmpty) continue;
      final records = await _client
          .from(kTableAttendanceRecords)
          .select('status')
          .eq('session_id', sid);
      final list = records as List<dynamic>;
      final total = list.length;
      final present = list.where((e) {
        final st = Map<String, dynamic>.from(e as Map)['status'] as String?;
        return st == 'present' || st == 'late';
      }).length;
      final pct = total == 0 ? 0.0 : (present * 100.0) / total;
      out.add({
        'date': s['date'],
        'percentage': pct,
      });
    }
    return out;
  }

  Future<List<AttendanceWarningRecipient>> getWarningRecipientsForMonth({
    required String courseId,
    required DateTime month,
    int thresholdPct = 75,
  }) async {
    final rows = await getCourseMonthlySummary(courseId: courseId, month: month);
    if (rows.isEmpty) return const <AttendanceWarningRecipient>[];
    final warning = rows.where((e) => e.percentage < thresholdPct).toList();
    if (warning.isEmpty) return const <AttendanceWarningRecipient>[];
    final ids = warning.map((e) => e.studentId).toList();
    final users = await _client
        .from(kTableUsers)
        .select('id, phone, guardian_phone')
        .inFilter('id', ids);
    final contactById = <String, Map<String, dynamic>>{};
    for (final raw in users as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      contactById[m['id'] as String] = m;
    }
    return warning
        .map((e) => AttendanceWarningRecipient(
              studentId: e.studentId,
              studentNameBn: e.studentNameBn,
              studentCode: e.studentCode,
              phone: contactById[e.studentId]?['phone'] as String?,
              guardianPhone: contactById[e.studentId]?['guardian_phone'] as String?,
              percentage: e.percentage,
            ))
        .toList();
  }

  Future<List<AttendanceWeeklyRecipient>> getWeeklyRecipients({
    required String courseId,
  }) async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    final sessions = await _client
        .from(kTableAttendanceSessions)
        .select('id')
        .eq('course_id', courseId)
        .gte('date', _sqlDate(start))
        .lte('date', _sqlDate(end));
    final sessionIds = (sessions as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['id'] as String)
        .toList();
    if (sessionIds.isEmpty) return const <AttendanceWeeklyRecipient>[];
    final recs = await _client
        .from(kTableAttendanceRecords)
        .select('student_id, status, users!inner(full_name_bn, student_id)')
        .inFilter('session_id', sessionIds);
    final agg = <String, _Agg>{};
    for (final raw in recs as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      final uid = m['student_id'] as String? ?? '';
      if (uid.isEmpty) continue;
      final u = _relatedUserMap(m['users']);
      final a = agg.putIfAbsent(
        uid,
        () => _Agg(studentId: uid, studentNameBn: u['full_name_bn'] as String? ?? '—', studentCode: u['student_id'] as String?),
      );
      a.total++;
      final st = m['status'] as String? ?? 'absent';
      if (st == 'present' || st == 'late') {
        a.present++;
      } else {
        a.absent++;
      }
    }
    return agg.values
        .map((a) => AttendanceWeeklyRecipient(
              studentId: a.studentId,
              studentNameBn: a.studentNameBn,
              studentCode: a.studentCode,
              percentage: a.total == 0 ? 0 : (a.present * 100.0) / a.total,
            ))
        .toList();
  }

  Future<AttendanceSettingsModel> getAttendanceSettings() async {
    final row = await _client
        .from(kTableAttendanceSettings)
        .select()
        .eq('singleton_key', 1)
        .maybeSingle();
    if (row == null) return const AttendanceSettingsModel();
    return AttendanceSettingsModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<AttendanceSettingsModel> saveAttendanceSettings(
    AttendanceSettingsModel settings,
  ) async {
    final row = await _client
        .from(kTableAttendanceSettings)
        .upsert(
          settings.toUpsertJson(updatedBy: _client.auth.currentUser?.id),
          onConflict: 'singleton_key',
        )
        .select()
        .single();
    return AttendanceSettingsModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Existing marks for this session (`student_id` → `present` / `absent` / `late`).
  Future<Map<String, String>> getRecordStatusesForSession(String sessionId) async {
    final rows = await _client
        .from(kTableAttendanceRecords)
        .select('student_id, status')
        .eq('session_id', sessionId);

    final map = <String, String>{};
    for (final raw in rows as List<dynamic>) {
      final m = Map<String, dynamic>.from(raw as Map);
      map[m['student_id'] as String] = m['status'] as String;
    }
    return map;
  }

  /// Inserts or updates one row (unique on `session_id`, `student_id`).
  Future<void> upsertAttendanceRecord({
    required String sessionId,
    required String studentId,
    required String status,
  }) async {
    await _client.from(kTableAttendanceRecords).upsert(
      <String, dynamic>{
        'session_id': sessionId,
        'student_id': studentId,
        'status': status,
      },
      onConflict: 'session_id,student_id',
    );
  }

  static String _sqlDate(DateTime d) {
    final u = DateTime.utc(d.year, d.month, d.day);
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _relatedUserMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return const <String, dynamic>{};
  }
}

class _Agg {
  _Agg({
    required this.studentId,
    required this.studentNameBn,
    required this.studentCode,
  });

  final String studentId;
  final String studentNameBn;
  final String? studentCode;
  int total = 0;
  int present = 0;
  int absent = 0;
}
