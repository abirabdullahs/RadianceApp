/// Matches `enrollments` table (see `plan/03_database_roadmap.md`).
enum EnrollmentStatus {
  active,
  suspended,
  completed;

  static EnrollmentStatus fromJson(String value) {
    return EnrollmentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EnrollmentStatus.active,
    );
  }

  String toJson() => name;
}

class EnrollmentModel {
  const EnrollmentModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    this.enrolledAt,
    required this.status,
    this.enrolledBy,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String courseId;
  final DateTime? enrolledAt;
  final EnrollmentStatus status;
  final String? enrolledBy;
  final DateTime? createdAt;

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      enrolledAt: _parseDate(json['enrolled_at']),
      status: EnrollmentStatus.fromJson(json['status'] as String? ?? 'active'),
      enrolledBy: json['enrolled_by'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'student_id': studentId,
      'course_id': courseId,
      'enrolled_at': enrolledAt == null
          ? null
          : _dateToSqlDate(enrolledAt!),
      'status': status.toJson(),
      'enrolled_by': enrolledBy,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  EnrollmentModel copyWith({
    String? id,
    String? studentId,
    String? courseId,
    DateTime? enrolledAt,
    EnrollmentStatus? status,
    String? enrolledBy,
    DateTime? createdAt,
  }) {
    return EnrollmentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      status: status ?? this.status,
      enrolledBy: enrolledBy ?? this.enrolledBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _parseDate(dynamic value) {
  final dt = _parseDateTime(value);
  if (dt == null) return null;
  return DateTime.utc(dt.year, dt.month, dt.day);
}

String _dateToSqlDate(DateTime d) {
  final u = DateTime.utc(d.year, d.month, d.day);
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
