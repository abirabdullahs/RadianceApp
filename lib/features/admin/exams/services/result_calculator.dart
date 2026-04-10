import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants.dart';
import '../../../../core/services/notification_edge_service.dart';
import '../../../../core/supabase_client.dart';

/// Computes scores from submissions vs question keys, upserts [results], ranks via RPC,
/// marks exam [result_published], and queues [notifications] for FCM workers.
class ResultCalculator {
  ResultCalculator({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  /// Loads exam + questions + submissions, writes scores, ranks, publishes exam, notifies students.
  Future<void> calculateResults(String examId) async {
    final examRow = await _client
        .from(kTableExams)
        .select('id, title, total_marks, pass_marks, negative_marking')
        .eq('id', examId)
        .maybeSingle();

    if (examRow == null) {
      throw StateError('Exam not found: $examId');
    }

    final exam = Map<String, dynamic>.from(examRow as Map);
    final examTitle = exam['title'] as String? ?? 'পরীক্ষা';
    final totalMarksExam = _toDouble(exam['total_marks']);
    final passMarks = _toDouble(exam['pass_marks']);
    final negativeMarking = _toDouble(exam['negative_marking']);

    final qRows = await _client
        .from(kTableQuestions)
        .select('id, correct_option, marks')
        .eq('exam_id', examId)
        .order('display_order', ascending: true);

    final questions = (qRows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (questions.isEmpty) {
      throw StateError('No questions for exam $examId');
    }

    final subRows = await _client
        .from(kTableExamSubmissions)
        .select('id, student_id, answers')
        .eq('exam_id', examId);

    final submissions = (subRows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final resultPayloads = <Map<String, dynamic>>[];

    for (final sub in submissions) {
      final subId = sub['id'] as String;
      final studentId = sub['student_id'] as String;
      final answersRaw = sub['answers'];
      final answers = answersRaw is Map
          ? Map<String, dynamic>.from(answersRaw)
          : <String, dynamic>{};

      var score = 0.0;
      var correct = 0;
      var wrong = 0;

      for (final q in questions) {
        final qid = q['id'] as String;
        final correctOpt =
            (q['correct_option'] as String? ?? 'A').trim().toUpperCase();
        final qMarks = _toDouble(q['marks'], fallback: 1);
        final chosen = _normalizeOption(answers[qid]);

        if (chosen == null || chosen.isEmpty) {
          wrong++;
          score -= negativeMarking;
        } else if (chosen == correctOpt) {
          correct++;
          score += qMarks;
        } else {
          wrong++;
          score -= negativeMarking;
        }
      }

      score = math.max(0, score);

      await _client.from(kTableExamSubmissions).update(<String, dynamic>{
        'score': score,
        'total_correct': correct,
        'total_wrong': wrong,
      }).eq('id', subId);

      final percentage = totalMarksExam > 0
          ? (score / totalMarksExam) * 100.0
          : 0.0;
      final grade = _gradeFromPercentage(percentage);
      final passed = score >= passMarks;

      resultPayloads.add(<String, dynamic>{
        'exam_id': examId,
        'student_id': studentId,
        'score': score,
        'total_marks': totalMarksExam,
        'percentage': double.parse(percentage.toStringAsFixed(2)),
        'grade': grade,
        'is_passed': passed,
        'published_at': nowIso,
      });
    }

    if (resultPayloads.isNotEmpty) {
      await _client.from(kTableResults).upsert(
            resultPayloads,
            onConflict: 'exam_id,student_id',
          );
    }

    await _client.rpc<void>(
      'calculate_exam_ranks',
      params: <String, dynamic>{'p_exam_id': examId},
    );

    await _client.from(kTableExams).update(<String, dynamic>{
      'status': 'result_published',
      'updated_at': nowIso,
    }).eq('id', examId);

    final sidList =
        submissions.map((s) => s['student_id'] as String).toList();
    await _queueResultNotifications(
      examId: examId,
      examTitle: examTitle,
      studentIds: sidList,
    );
    await NotificationEdgeService().invokeSendNotification(
      userIds: sidList.toSet().toList(),
      title: 'ফলাফল প্রকাশিত',
      body: '$examTitle — রেজাল্ট ও লিডারবোর্ড দেখতে ট্যাপ করুন।',
      actionRoute: '/student/results',
      type: 'result',
    );
  }

  /// Offline exam result publish: admin provides per-student obtained marks.
  Future<void> publishOfflineResults({
    required String examId,
    required double totalMarks,
    required List<OfflineResultInput> inputs,
  }) async {
    final examRow = await _client
        .from(kTableExams)
        .select('id, title, pass_marks')
        .eq('id', examId)
        .maybeSingle();
    if (examRow == null) throw StateError('Exam not found: $examId');
    final exam = Map<String, dynamic>.from(examRow as Map);
    final examTitle = exam['title'] as String? ?? 'পরীক্ষা';
    final passMarks = _toDouble(exam['pass_marks'], fallback: totalMarks * 0.4);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = <Map<String, dynamic>>[];
    final studentIds = <String>[];
    for (final input in inputs) {
      final score = input.obtainedMarks.clamp(0, totalMarks).toDouble();
      final percentage = totalMarks > 0 ? (score / totalMarks) * 100 : 0.0;
      payload.add(<String, dynamic>{
        'exam_id': examId,
        'student_id': input.studentId,
        'score': score,
        'total_marks': totalMarks,
        'percentage': double.parse(percentage.toStringAsFixed(2)),
        'grade': _gradeFromPercentage(percentage),
        'is_passed': score >= passMarks,
        'published_at': nowIso,
      });
      studentIds.add(input.studentId);
    }
    if (payload.isNotEmpty) {
      await _client.from(kTableResults).upsert(payload, onConflict: 'exam_id,student_id');
    }

    await _client.rpc<void>(
      'calculate_exam_ranks',
      params: <String, dynamic>{'p_exam_id': examId},
    );
    await _client.from(kTableExams).update(<String, dynamic>{
      'status': 'result_published',
      'updated_at': nowIso,
    }).eq('id', examId);

    await _queueResultNotifications(
      examId: examId,
      examTitle: examTitle,
      studentIds: studentIds,
    );
    await NotificationEdgeService().invokeSendNotification(
      userIds: studentIds.toSet().toList(),
      title: 'ফলাফল প্রকাশিত',
      body: '$examTitle — রেজাল্ট ও লিডারবোর্ড দেখতে ট্যাপ করুন।',
      actionRoute: '/student/results',
      type: 'result',
    );
  }

  Future<void> _queueResultNotifications({
    required String examId,
    required String examTitle,
    required List<String> studentIds,
  }) async {
    if (studentIds.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final uid in studentIds.toSet()) {
      rows.add(<String, dynamic>{
        'user_id': uid,
        'title': 'ফলাফল প্রকাশিত',
        'body': '$examTitle — রেজাল্ট ও লিডারবোর্ড দেখতে ট্যাপ করুন।',
        'type': 'result',
        'action_route': '/student/results',
        'is_read': false,
        'fcm_sent': false,
      });
    }

    await _client.from(kTableNotifications).insert(rows);
  }

  static String? _normalizeOption(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim().toUpperCase();
    if (s.isEmpty) return null;
    if (s.length == 1 && 'ABCD'.contains(s)) return s;
    return s;
  }

  static double _toDouble(dynamic v, {double fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Simple percentage → letter (tune to institutional policy if needed).
  static String _gradeFromPercentage(double percentage) {
    if (percentage >= 80) return 'A+';
    if (percentage >= 70) return 'A';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 40) return 'D';
    return 'F';
  }
}

class OfflineResultInput {
  const OfflineResultInput({
    required this.studentId,
    required this.obtainedMarks,
  });

  final String studentId;
  final double obtainedMarks;
}
