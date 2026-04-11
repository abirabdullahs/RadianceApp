import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/enrollment_model.dart';
import '../../../../shared/models/exam_model.dart';
import '../../../../shared/models/question_model.dart';

/// Student: list exams for enrolled courses, take exam, submit answers.
class StudentExamRepository {
  StudentExamRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  static const _examRowSelect =
      'id,course_id,subject_id,chapter_ids,exam_mode,title,description,instructions,duration_minutes,start_time,end_time,exam_date,venue,total_marks,pass_marks,marks_per_question,shuffle_questions,show_result_immediately,negative_marking,status,created_by,created_at,updated_at';

  static const _questionRowSelect =
      'id,exam_id,question_text,image_url,option_a,option_b,option_c,option_d,correct_option,marks,explanation,display_order';

  Future<List<ExamModel>> listExamsForCurrentStudent() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final en = await _client
        .from(kTableEnrollments)
        .select('course_id')
        .eq('student_id', uid)
        .eq('status', EnrollmentStatus.active.toJson());
    final courseIds = (en as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map)['course_id'] as String)
        .toSet()
        .toList();
    if (courseIds.isEmpty) return [];

    final rows = await _client
        .from(kTableExams)
        .select(_examRowSelect)
        .inFilter('course_id', courseIds)
        .order('start_time', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => ExamModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ExamModel> getExam(String id) async {
    final row =
        await _client.from(kTableExams).select(_examRowSelect).eq('id', id).single();
    return ExamModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<QuestionModel>> listQuestions(String examId) async {
    final rows = await _client
        .from(kTableQuestions)
        .select(_questionRowSelect)
        .eq('exam_id', examId)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Ensures a submission row exists for the current student.
  Future<void> ensureSubmissionStarted(String examId) async {
    final uid = _client.auth.currentUser!.id;
    final existing = await _client
        .from(kTableExamSubmissions)
        .select('id')
        .eq('exam_id', examId)
        .eq('student_id', uid)
        .maybeSingle();
    if (existing != null) return;

    await _client.from(kTableExamSubmissions).insert(<String, dynamic>{
      'id': _uuid.v4(),
      'exam_id': examId,
      'student_id': uid,
      'answers': <String, dynamic>{},
      'started_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getSubmissionAnswers(String examId) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from(kTableExamSubmissions)
        .select('answers')
        .eq('exam_id', examId)
        .eq('student_id', uid)
        .maybeSingle();
    if (row == null) return {};
    final a = Map<String, dynamic>.from(row)['answers'];
    if (a is Map) return Map<String, dynamic>.from(a);
    return {};
  }

  Future<Map<String, dynamic>?> getSubmissionState(String examId) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from(kTableExamSubmissions)
        .select('answers, started_at, submitted_at')
        .eq('exam_id', examId)
        .eq('student_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> saveAnswers(String examId, Map<String, dynamic> answers) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from(kTableExamSubmissions).update(<String, dynamic>{
      'answers': answers,
    }).eq('exam_id', examId).eq('student_id', uid);
  }

  Future<void> submitExam(String examId) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from(kTableExamSubmissions).update(<String, dynamic>{
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('exam_id', examId).eq('student_id', uid);
  }
}
