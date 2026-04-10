import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/supabase_client.dart';

class ResultRepository {
  ResultRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getStudentResults({
    required String studentId,
    String? examType,
  }) async {
    var q = _client
        .from(kTableResults)
        .select(
          'id,exam_id,student_id,score,total_marks,percentage,grade,rank,'
          'is_passed,exam_type,total_correct,total_wrong,total_skipped,'
          'negative_deduction,time_taken_seconds,remarks,is_published,published_at,'
          'exams(id,title,exam_mode,status,start_time,course_id,subject_id)',
        )
        .eq('student_id', studentId)
        .eq('is_published', true);
    if (examType != null && examType.isNotEmpty) {
      q = q.eq('exam_type', examType);
    }
    final rows = await q.order('published_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String examId) async {
    final rows = await _client
        .from(kTableResults)
        .select(
          'id,student_id,score,total_marks,percentage,grade,rank,is_passed,'
          'exam_type,time_taken_seconds,users(full_name_bn,student_id,avatar_url)',
        )
        .eq('exam_id', examId)
        .eq('is_published', true)
        .order('rank', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listAdminExamResults(String examId) async {
    final rows = await _client
        .from(kTableResults)
        .select(
          'id,exam_id,student_id,score,total_marks,percentage,grade,rank,is_passed,'
          'exam_type,total_correct,total_wrong,total_skipped,negative_deduction,'
          'time_taken_seconds,remarks,is_published,published_at,users(full_name_bn,student_id)',
        )
        .eq('exam_id', examId)
        .order('rank', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>?> getStudentResultDetail({
    required String examId,
    required String studentId,
  }) async {
    final row = await _client
        .from(kTableResults)
        .select(
          'id,exam_id,student_id,score,total_marks,percentage,grade,rank,is_passed,'
          'exam_type,total_correct,total_wrong,total_skipped,negative_deduction,'
          'time_taken_seconds,remarks,is_published,published_at,'
          'exams(id,title,exam_mode,status,start_time,end_time,total_marks,pass_marks)',
        )
        .eq('exam_id', examId)
        .eq('student_id', studentId)
        .eq('is_published', true)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> getMyPerformanceRecent({
    required String studentId,
    int limit = 10,
  }) async {
    final rows = await _client
        .from(kTableResults)
        .select(
          'id,exam_id,score,total_marks,percentage,rank,published_at,exam_type,'
          'exams(title,subject_id)',
        )
        .eq('student_id', studentId)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
