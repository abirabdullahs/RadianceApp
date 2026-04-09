import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
        'full_name_bn.ilike.$p,full_name_en.ilike.$p,phone.ilike.$p,student_id.ilike.$p',
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

  /// Creates Auth user (phone + password) then inserts `public.users` with the same `id`.
  ///
  /// Restores the admin session afterward via [Session.refreshToken] so the admin
  /// stays signed in. Requires the dashboard to allow phone signup (confirm settings).
  Future<UserModel> addStudent(UserModel student, File? photoFile) async {
    final adminSession = _client.auth.currentSession;
    if (adminSession?.refreshToken == null) {
      throw StateError('Admin session missing; cannot create student account');
    }
    final adminRefresh = adminSession!.refreshToken!;

    final phoneE164 = _toE164Bd(student.phone);
    final password = _randomPassword();

    final signUpRes = await _client.auth.signUp(
      phone: phoneE164,
      password: password,
      data: <String, dynamic>{
        'role': UserRole.student.toJson(),
      },
    );

    final newUser = signUpRes.user;
    if (newUser == null) {
      await _restoreAdminSession(adminRefresh);
      throw StateError('Sign up did not return a user (check phone confirmation settings)');
    }

    try {
      String? avatarUrl;
      if (photoFile != null) {
        avatarUrl = await _uploadAvatar(photoFile, newUser.id);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final row = <String, dynamic>{
        'id': newUser.id,
        'phone': student.phone,
        'email': student.email,
        'full_name_bn': student.fullNameBn,
        'full_name_en': student.fullNameEn,
        'avatar_url': avatarUrl ?? student.avatarUrl,
        'role': UserRole.student.toJson(),
        'student_id': student.studentId,
        'date_of_birth': student.dateOfBirth == null
            ? null
            : '${student.dateOfBirth!.year.toString().padLeft(4, '0')}-'
                '${student.dateOfBirth!.month.toString().padLeft(2, '0')}-'
                '${student.dateOfBirth!.day.toString().padLeft(2, '0')}',
        'guardian_phone': student.guardianPhone,
        'address': student.address,
        'class_level': student.classLevel?.toJson(),
        'fcm_token': student.fcmToken,
        'is_active': student.isActive,
        'created_at': now,
        'updated_at': now,
      };

      final inserted = await _client.from(kTableUsers).insert(row).select().single();

      return UserModel.fromJson(Map<String, dynamic>.from(inserted));
    } finally {
      await _restoreAdminSession(adminRefresh);
    }
  }

  Future<void> _restoreAdminSession(String adminRefreshToken) async {
    await _client.auth.setSession(adminRefreshToken);
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

  static String _randomPassword() {
    final r = Random.secure();
    final bytes = List<int>.generate(48, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }
}

/// Bangladesh local or E.164 → `+8801...` for Supabase Auth.
String _toE164Bd(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[\s-]'), '');
  if (s.isEmpty) {
    throw const FormatException('Phone number is empty');
  }
  if (s.startsWith('+')) {
    return s;
  }
  if (s.startsWith('00')) {
    s = s.substring(2);
  }
  if (s.startsWith('0')) {
    s = '880${s.substring(1)}';
  } else if (!s.startsWith('880')) {
    if (s.length == 10) {
      s = '880$s';
    } else {
      throw FormatException('Unsupported phone format: $raw');
    }
  }
  return '+$s';
}
