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
    this.publishedAt,
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
  final DateTime? publishedAt;

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
      publishedAt: _parseDateTime(json['published_at']),
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
      'published_at': publishedAt?.toUtc().toIso8601String(),
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
