class AdvanceBalanceModel {
  const AdvanceBalanceModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.balance,
    this.lastUpdated,
  });

  final String id;
  final String studentId;
  final String courseId;
  final double balance;
  final DateTime? lastUpdated;

  factory AdvanceBalanceModel.fromJson(Map<String, dynamic> json) {
    return AdvanceBalanceModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      balance: _parseDouble(json['balance']),
      lastUpdated: _parseDateTime(json['last_updated']),
    );
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
