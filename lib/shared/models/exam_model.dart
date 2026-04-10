/// Matches `exams` table (plan/03_database_roadmap.md).
class ExamModel {
  const ExamModel({
    required this.id,
    required this.courseId,
    this.subjectId,
    this.chapterIds = const [],
    this.examMode = 'online',
    required this.title,
    this.instructions,
    required this.durationMinutes,
    this.startTime,
    this.endTime,
    this.totalMarks,
    this.passMarks,
    this.shuffleQuestions = false,
    this.showResultImmediately = true,
    this.negativeMarking = 0,
    required this.status,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String courseId;
  final String? subjectId;
  final List<String> chapterIds;
  final String examMode;
  final String title;
  final String? instructions;
  final int durationMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? totalMarks;
  final double? passMarks;
  final bool shuffleQuestions;
  final bool showResultImmediately;
  final double negativeMarking;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      subjectId: json['subject_id'] as String?,
      chapterIds: _parseStringList(json['chapter_ids']),
      examMode: (json['exam_mode'] as String?) ?? 'online',
      title: json['title'] as String,
      instructions: json['instructions'] as String?,
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      startTime: _parseDt(json['start_time']),
      endTime: _parseDt(json['end_time']),
      totalMarks: _parseDouble(json['total_marks']),
      passMarks: _parseDouble(json['pass_marks']),
      shuffleQuestions: json['shuffle_questions'] as bool? ?? false,
      showResultImmediately: json['show_result_immediately'] as bool? ?? true,
      negativeMarking: _parseDouble(json['negative_marking']) ?? 0,
      status: json['status'] as String? ?? 'draft',
      createdBy: json['created_by'] as String?,
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'course_id': courseId,
      'subject_id': subjectId,
      'chapter_ids': chapterIds,
      'exam_mode': examMode,
      'title': title,
      'instructions': instructions,
      'duration_minutes': durationMinutes,
      'start_time': startTime?.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'total_marks': totalMarks,
      'pass_marks': passMarks,
      'shuffle_questions': shuffleQuestions,
      'show_result_immediately': showResultImmediately,
      'negative_marking': negativeMarking,
      'status': status,
      'created_by': createdBy,
    };
  }
}

List<String> _parseStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return const [];
}

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
