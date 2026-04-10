import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants.dart';
import '../../../../core/supabase_client.dart';
import '../../../../shared/models/exam_model.dart';
import '../../../../shared/models/question_model.dart';

/// Admin: exams and questions CRUD.
class ExamRepository {
  ExamRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  Future<List<ExamModel>> listExams() async {
    final rows = await _client
        .from(kTableExams)
        .select()
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => ExamModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ExamModel> getExam(String id) async {
    final row = await _client.from(kTableExams).select().eq('id', id).single();
    return ExamModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<ExamModel> createExam({
    required String courseId,
    String? subjectId,
    List<String> chapterIds = const [],
    String examMode = 'online',
    required String title,
    String? description,
    String? instructions,
    required int durationMinutes,
    double? totalMarks,
    double? passMarks,
    double negativeMarking = 0,
    bool shuffleQuestions = false,
    bool showResultImmediately = true,
    String status = 'draft',
    DateTime? startTime,
    DateTime? endTime,
    DateTime? examDate,
    String? venue,
    double? marksPerQuestion,
  }) async {
    final id = _uuid.v4();
    final uid = _client.auth.currentUser?.id;
    final now = DateTime.now().toUtc().toIso8601String();
    final insert = <String, dynamic>{
      'id': id,
      'course_id': courseId,
      'subject_id': subjectId,
      'chapter_ids': chapterIds,
      'exam_mode': examMode,
      'title': title,
      'description': description,
      'instructions': instructions,
      'duration_minutes': durationMinutes,
      'start_time': startTime?.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'exam_date': examDate?.toUtc().toIso8601String(),
      'venue': venue,
      'total_marks': totalMarks,
      'pass_marks': passMarks,
      'marks_per_question': marksPerQuestion,
      'negative_marking': negativeMarking,
      'shuffle_questions': shuffleQuestions,
      'show_result_immediately': showResultImmediately,
      'status': status,
      'created_by': uid,
      'created_at': now,
      'updated_at': now,
    };
    final row = await _client.from(kTableExams).insert(insert).select().single();
    return ExamModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<ExamModel> updateExam(ExamModel exam) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(kTableExams)
        .update({
          'course_id': exam.courseId,
          'subject_id': exam.subjectId,
          'chapter_ids': exam.chapterIds,
          'exam_mode': exam.examMode,
          'title': exam.title,
          'description': exam.description,
          'instructions': exam.instructions,
          'duration_minutes': exam.durationMinutes,
          'start_time': exam.startTime?.toUtc().toIso8601String(),
          'end_time': exam.endTime?.toUtc().toIso8601String(),
          'exam_date': exam.examDate?.toUtc().toIso8601String(),
          'venue': exam.venue,
          'total_marks': exam.totalMarks,
          'pass_marks': exam.passMarks,
          'marks_per_question': exam.marksPerQuestion,
          'negative_marking': exam.negativeMarking,
          'shuffle_questions': exam.shuffleQuestions,
          'show_result_immediately': exam.showResultImmediately,
          'status': exam.status,
          'updated_at': now,
        })
        .eq('id', exam.id)
        .select()
        .single();
    return ExamModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<QuestionModel>> listQuestions(String examId) async {
    final rows = await _client
        .from(kTableQuestions)
        .select()
        .eq('exam_id', examId)
        .order('display_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<QuestionModel> addQuestion({
    required String examId,
    required String questionText,
    String? imageUrl,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    double marks = 1,
    String? explanation,
    int displayOrder = 0,
  }) async {
    final id = _uuid.v4();
    final row = await _client.from(kTableQuestions).insert(<String, dynamic>{
      'id': id,
      'exam_id': examId,
      'question_text': questionText,
      'image_url': imageUrl,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_option': correctOption.toUpperCase(),
      'marks': marks,
      'explanation': explanation,
      'display_order': displayOrder,
    }).select().single();
    return QuestionModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteQuestion(String questionId) async {
    await _client.from(kTableQuestions).delete().eq('id', questionId);
  }

  Future<void> setExamStatus(String examId, String status) async {
    await _client.from(kTableExams).update(<String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', examId);
  }
}
