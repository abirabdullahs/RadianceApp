import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/models/result_model.dart';
import '../../../../shared/models/user_model.dart';

/// Student profiles, auth provisioning, enrollments, payments, attendance, results.
class StudentRepository {
  StudentRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  /// Lists students (`role = student`). Optional [searchQuery] matches name / phone / student_id.
  /// [courseId] limits to students enrolled in that course.
  Future<List<UserModel>> getStudents({
    String? searchQuery,
    String? courseId,
  }) async {
    List<String>? idFilter;
    if (courseId != null && courseId.isNotEmpty) {
      final en = await _client
          .from(kTableEnrollments)
          .select('student_id')
          .eq('course_id', courseId);
      idFilter = (en as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map)['student_id'] as String)
          .toList();
      if (idFilter.isEmpty) return [];
    }

    var q = _client.from(kTableUsers).select().eq('role', UserRole.student.toJson());

    if (idFilter != null) {
      q = q.inFilter('id', idFilter);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final raw = searchQuery.trim();
      final escaped = raw.replaceAll(RegExp(r'[%*,()]'), '');
      final p = '%$escaped%';
      q = q.or(
        'full_name_bn.ilike.$p,full_name_en.ilike.$p,phone.ilike.$p,student_id.ilike.$p,college.ilike.$p',
      );
    }

    final rows = await q.order('created_at', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<UserModel> getStudentById(String id) async {
    final row = await _client
        .from(kTableUsers)
        .select()
        .eq('id', id)
        .eq('role', UserRole.student.toJson())
        .maybeSingle();
    if (row == null) {
      throw StateError('Student not found: $id');
    }
    return UserModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Creates Auth user + `public.users` via Edge Function `create-student` (service role).
  /// Password rule: [studentPasswordFromPhoneDigits] (last 9 digits of mobile).
  Future<UserModel> addStudent(UserModel student, File? photoFile) async {
    if (_client.auth.currentSession == null) {
      throw StateError('অ্যাডমিন সেশন নেই। আবার লগইন করুন।');
    }
    // Refresh access token so Edge Function gateway accepts JWT (avoids 401 invalid JWT).
    final refreshed = await _client.auth.refreshSession();
    if (refreshed.session == null) {
      throw StateError('সেশন মেয়াদ শেষ। লগআউট করে আবার লগইন করুন।');
    }

    final body = <String, dynamic>{
      'phone': student.phone.trim(),
      'full_name_bn': student.fullNameBn,
      if (student.fullNameEn != null && student.fullNameEn!.trim().isNotEmpty)
        'full_name_en': student.fullNameEn!.trim(),
      if (student.guardianPhone != null && student.guardianPhone!.trim().isNotEmpty)
        'guardian_phone': student.guardianPhone!.trim(),
      if (student.address != null && student.address!.trim().isNotEmpty)
        'address': student.address!.trim(),
      if (student.college != null && student.college!.trim().isNotEmpty)
        'college': student.college!.trim(),
      if (student.classLevel != null) 'class_level': student.classLevel!.toJson(),
      if (student.dateOfBirth != null)
        'date_of_birth':
            '${student.dateOfBirth!.year.toString().padLeft(4, '0')}-'
            '${student.dateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${student.dateOfBirth!.day.toString().padLeft(2, '0')}',
    };

    // Non-2xx responses throw [FunctionException]; they never return a [FunctionResponse].
    final FunctionResponse res = await _invokeCreateStudent(body);

    final raw = res.data;
    if (raw is! Map) {
      throw StateError('Unexpected response from create-student');
    }
    final data = Map<String, dynamic>.from(raw);
    final rowRaw = data['row'];
    if (rowRaw is! Map) {
      throw StateError('create-student: missing row');
    }
    var model = UserModel.fromJson(Map<String, dynamic>.from(rowRaw));

    if (photoFile != null) {
      final url = await _uploadAvatar(photoFile, model.id);
      final updated = await _client
          .from(kTableUsers)
          .update({
            'avatar_url': url,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', model.id)
          .select()
          .single();
      model = UserModel.fromJson(Map<String, dynamic>.from(updated));
    }

    return model;
  }

  Future<UserModel> updateStudent(UserModel student, File? newPhoto) async {
    String? avatarUrl = student.avatarUrl;
    if (newPhoto != null) {
      avatarUrl = await _uploadAvatar(newPhoto, student.id);
    }

    final updated = await _client
        .from(kTableUsers)
        .update({
          'phone': student.phone,
          'email': student.email,
          'full_name_bn': student.fullNameBn,
          'full_name_en': student.fullNameEn,
          'avatar_url': avatarUrl,
          'student_id': student.studentId,
          'date_of_birth': student.dateOfBirth == null
              ? null
              : '${student.dateOfBirth!.year.toString().padLeft(4, '0')}-'
                  '${student.dateOfBirth!.month.toString().padLeft(2, '0')}-'
                  '${student.dateOfBirth!.day.toString().padLeft(2, '0')}',
          'guardian_phone': student.guardianPhone,
          'address': student.address,
          'college': student.college,
          'class_level': student.classLevel?.toJson(),
          'fcm_token': student.fcmToken,
          'is_active': student.isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', student.id)
        .select()
        .single();

    return UserModel.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Student self-service: updates name, contact extras, avatar — not phone/email/student_id/role.
  Future<UserModel> updateMyProfile(UserModel student, File? newPhoto) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('লগইন নেই');
    if (student.id != uid) throw StateError('অননুমোদিত');

    String? avatarUrl = student.avatarUrl;
    if (newPhoto != null) {
      avatarUrl = await _uploadAvatar(newPhoto, student.id);
    }

    final updated = await _client
        .from(kTableUsers)
        .update({
          'full_name_bn': student.fullNameBn,
          'full_name_en': student.fullNameEn,
          'avatar_url': avatarUrl,
          'date_of_birth': student.dateOfBirth == null
              ? null
              : '${student.dateOfBirth!.year.toString().padLeft(4, '0')}-'
                  '${student.dateOfBirth!.month.toString().padLeft(2, '0')}-'
                  '${student.dateOfBirth!.day.toString().padLeft(2, '0')}',
          'guardian_phone': student.guardianPhone,
          'address': student.address,
          'college': student.college,
          'class_level': student.classLevel?.toJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid)
        .select()
        .single();

    return UserModel.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<void> deactivateStudent(String id) async {
    await _client.from(kTableUsers).update({
      'is_active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> enrollStudentInCourse(String studentId, String courseId) async {
    final adminId = _client.auth.currentUser?.id;
    final now = DateTime.now().toUtc().toIso8601String();
    final d = DateTime.now();
    final enrolledDate =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    await _client.from(kTableEnrollments).insert({
      'id': _uuid.v4(),
      'student_id': studentId,
      'course_id': courseId,
      'enrolled_at': enrolledDate,
      'status': EnrollmentStatus.active.toJson(),
      'enrolled_by': adminId,
      'created_at': now,
    });
  }

  /// Active enrollments for the signed-in student (same as [getStudentEnrollments] with auth id).
  Future<List<EnrollmentModel>> getMyEnrollments() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    return getStudentEnrollments(uid);
  }

  Future<List<EnrollmentModel>> getStudentEnrollments(String studentId) async {
    final rows = await _client
        .from(kTableEnrollments)
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map((e) => EnrollmentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PaymentModel>> getStudentPayments(String studentId) async {
    final rows = await _client
        .from(kTablePayments)
        .select()
        .eq('student_id', studentId)
        .order('paid_at', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [month] is `yyyy-MM` (e.g. `2025-04`). Counts attendance for sessions in that
  /// month only for courses the student is (or was) enrolled in.
  Future<Map<String, dynamic>> getStudentAttendanceSummary(
    String studentId,
    String month,
  ) async {
    final ym = _parseYearMonth(month);
    final start = DateTime.utc(ym.year, ym.month, 1);
    final end = DateTime.utc(ym.year, ym.month + 1, 0);

    final en = await _client
        .from(kTableEnrollments)
        .select('course_id')
        .eq('student_id', studentId)
        .eq('status', EnrollmentStatus.active.toJson());
    final courseIds = (en as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['course_id'] as String)
        .toSet()
        .toList();

    if (courseIds.isEmpty) {
      return <String, dynamic>{
        'month': month,
        'total_sessions': 0,
        'present': 0,
        'absent': 0,
        'late': 0,
        'percentage': null,
      };
    }

    final sessions = await _client
        .from(kTableAttendanceSessions)
        .select('id')
        .inFilter('course_id', courseIds)
        .gte('date', _dateToSql(start))
        .lte('date', _dateToSql(end));

    final sessionIds = (sessions as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['id'] as String)
        .toList();

    if (sessionIds.isEmpty) {
      return <String, dynamic>{
        'month': month,
        'total_sessions': 0,
        'present': 0,
        'absent': 0,
        'late': 0,
        'percentage': null,
      };
    }

    final recs = await _client
        .from(kTableAttendanceRecords)
        .select('status')
        .eq('student_id', studentId)
        .inFilter('session_id', sessionIds);

    var present = 0;
    var absent = 0;
    var late = 0;
    for (final e in recs as List<dynamic>) {
      final s = Map<String, dynamic>.from(e as Map)['status'] as String?;
      switch (s) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'absent':
        default:
          absent++;
          break;
      }
    }

    final total = present + absent + late;
    final pct = total == 0
        ? null
        : ((present + late) / total) * 100.0;

    return <String, dynamic>{
      'month': month,
      'total_sessions': total,
      'present': present,
      'absent': absent,
      'late': late,
      'percentage': pct,
    };
  }

  Future<List<ResultModel>> getStudentResults(String studentId) async {
    final rows = await _client
        .from(kTableResults)
        .select()
        .eq('student_id', studentId)
        .order('published_at', ascending: false);
    final list = rows as List<dynamic>;
    return list
        .map((e) => ResultModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<FunctionResponse> _invokeCreateStudent(Map<String, dynamic> body) async {
    Future<FunctionResponse> once() async {
      final session = _client.auth.currentSession;
      if (session == null) {
        throw StateError('অ্যাডমিন সেশন নেই। আবার লগইন করুন।');
      }
      // Force Bearer + apikey on each call. AuthHttpClient uses putIfAbsent on
      // Authorization; a stale header on the request would otherwise block the
      // fresh JWT and cause gateway "invalid JWT".
      return _client.functions.invoke(
        'create-student',
        body: body,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': resolvedSupabaseAnonKey,
        },
      );
    }

    try {
      return await once();
    } on FunctionException catch (e) {
      if (e.status == 401) {
        final again = await _client.auth.refreshSession();
        if (again.session == null) {
          throw StateError('সেশন মেয়াদ শেষ। লগআউট করে আবার লগইন করুন।');
        }
        try {
          return await once();
        } on FunctionException catch (e2) {
          _throwFromFunctionException(e2);
        }
      }
      _throwFromFunctionException(e);
    }
  }

  Never _throwFromFunctionException(FunctionException e) {
    final raw = e.details;
    final msg = raw is Map
        ? (raw['error'] ?? raw['message'] ?? raw.toString())
        : (raw is String && raw.isNotEmpty)
            ? raw
            : raw?.toString() ?? 'HTTP ${e.status}';
    final hint = raw is Map ? raw['hint'] as String? : null;
    final rp = e.reasonPhrase;
    final prefix = (rp != null && rp.isNotEmpty) ? '$rp: ' : '';
    throw StateError(
      e.status == 401
          ? '$prefix$msg${hint != null ? ' ($hint)' : ''} — অ্যাডমিন হিসেবে আবার লগইন করুন।'
          : '$prefix$msg',
    );
  }

  Future<String> _uploadAvatar(File file, String userId) async {
    final ext = _fileExtension(file.path);
    final path = 'users/$userId/avatar.$ext';
    await _client.storage.from(kStorageBucketAvatars).upload(
          path,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _mimeForExtension(ext),
          ),
        );
    return _client.storage.from(kStorageBucketAvatars).getPublicUrl(path);
  }

  static ({int year, int month}) _parseYearMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) {
      throw FormatException('month must be yyyy-MM, got: $month');
    }
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    if (m < 1 || m > 12) {
      throw FormatException('Invalid month in: $month');
    }
    return (year: y, month: m);
  }

  static String _dateToSql(DateTime d) {
    final u = DateTime.utc(d.year, d.month, d.day);
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  static String _fileExtension(String path) {
    final i = path.lastIndexOf('.');
    if (i == -1 || i == path.length - 1) return 'jpg';
    return path.substring(i + 1).toLowerCase();
  }

  static String _mimeForExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
