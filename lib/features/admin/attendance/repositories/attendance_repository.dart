import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/user_model.dart';

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
}
