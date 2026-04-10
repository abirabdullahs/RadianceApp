/// Matches `results` table (see `plan/03_database_roadmap.md`).
class ResultModel {
  const ResultModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.score,
    required this.totalMarks,
    this.percentage,
    this.grade,
    this.rank,
    this.isPassed,
    this.examType,
    this.totalCorrect,
    this.totalWrong,
    this.totalSkipped,
    this.negativeDeduction,
    this.timeTakenSeconds,
    this.remarks,
    this.isPublished,
    this.createdBy,
    this.publishedAt,
    this.updatedAt,
  });

  final String id;
  final String examId;
  final String studentId;
  final double score;
  final double totalMarks;
  final double? percentage;
  final String? grade;
  final int? rank;
  final bool? isPassed;
  final String? examType;
  final int? totalCorrect;
  final int? totalWrong;
  final int? totalSkipped;
  final double? negativeDeduction;
  final int? timeTakenSeconds;
  final String? remarks;
  final bool? isPublished;
  final String? createdBy;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    return ResultModel(
      id: json['id'] as String,
      examId: json['exam_id'] as String,
      studentId: json['student_id'] as String,
      score: _parseDouble(json['score']),
      totalMarks: _parseDouble(json['total_marks']),
      percentage: json['percentage'] != null
          ? _parseDouble(json['percentage'])
          : null,
      grade: json['grade'] as String?,
      rank: (json['rank'] as num?)?.toInt(),
      isPassed: json['is_passed'] as bool?,
      examType: json['exam_type'] as String?,
      totalCorrect: (json['total_correct'] as num?)?.toInt(),
      totalWrong: (json['total_wrong'] as num?)?.toInt(),
      totalSkipped: (json['total_skipped'] as num?)?.toInt(),
      negativeDeduction: json['negative_deduction'] != null
          ? _parseDouble(json['negative_deduction'])
          : null,
      timeTakenSeconds: (json['time_taken_seconds'] as num?)?.toInt(),
      remarks: json['remarks'] as String?,
      isPublished: json['is_published'] as bool?,
      createdBy: json['created_by'] as String?,
      publishedAt: _parseDateTime(json['published_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'exam_id': examId,
      'student_id': studentId,
      'score': score,
      'total_marks': totalMarks,
      'percentage': percentage,
      'grade': grade,
      'rank': rank,
      'is_passed': isPassed,
      'exam_type': examType,
      'total_correct': totalCorrect,
      'total_wrong': totalWrong,
      'total_skipped': totalSkipped,
      'negative_deduction': negativeDeduction,
      'time_taken_seconds': timeTakenSeconds,
      'remarks': remarks,
      'is_published': isPublished,
      'created_by': createdBy,
      'published_at': publishedAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
